// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

/// Toggler library is a state machine register that can be used as basis for
/// Models and ViewModels of **MVVM** and similar architectures.  It was
/// designed for use in singleton aka "ambient" Models.
///
/// Toggler manages state transitions with pre-commit state validation and
/// mutation. After any single change it first fires `fix` state transition
/// handler, then commits new state `fix` just prepared, then calls `after` or
/// signals `notifier` to inform outer world of changes made. This way Toggler
/// implements a unidirectional flow of state changes.
///
/// **Usage:** each bit in register represents a state of some entity (an _item_)
/// in a _Model_, or a whole _subModel_, or an async event. If said entity is a
/// boolean value, it can be represented by the very bit (of state) itself.
/// When reflected item changes an out signal with 1 set on a relevant bit
/// position can be sent to external observers via [ToggledNotifier].
///
/// Each [Toggler] instance may register activity of up to 63 (web:32) _Model_
/// members or events.  Then up to same number _Models_, each with its own
/// [Toggler] state register, can be reflected in an upper _Model_ (forming a
/// tree).
///
/// Toggler is small, fast, and it has no dependecies.
///
/// Test coverage: **100.0%** (202 of 202 lines)
library toggler;

// this woodoo is insane
import "src/const.dart" if (dart.library.io) 'src/const64.dart';
export 'src/const.dart' if (dart.library.io) 'src/const64.dart';

/// (63|33) highest bit index
const _hbi = bIndexMax + 1; // native ? 63 : 33;

/// (62|32) item max index bit
// const _imax = bIndexMax; //
/// finished, commit but do not call after/notifier  flag : hh bit 11
const _finish = 1 << 11; //
/// do revert flag : hh bit 11
const _fdone = 1 << 12; //
/// error flag :  hh bit 13
const _ferr = 1 << 13; //
/// on-hold flag : hh bit 14
const _fheld = 1 << 14; //
/// clear all flags
const _fZero = mTogglerPlatformMask; //

/// Toggler class keeps state changes register of up to 63 (32 for web) boolean
/// values (items) that can be manipulated one by one or in concert.
///
/// For ViewModels use, an independent _disabled_ flag is avaliable for every
/// state bit, then _radio group_ behaviour can be declared on up to 20 (10)
/// separated groups of items.  Each state bit value can be retrieved and set
/// using index[] operator, usually with a constant symbolic name.
///
/// By convention Toggler const index name has a `b` (bit index) name prefix,
/// then respective const bitmask uses `s` (select mask) prefix. Eg.
/// `const bPrize = 33; const sPrize = 1 << bPrize;`. Toggler based _Models_
/// by the same convention use `m` prefix.
///
/// _In package's tool/ directory there is a script that generates stub
/// constants together with their masks, for library user to rename later_.
class Toggler {
  /// togglee item 0..62 (0..31) value bit:  1:set 0:cleared.
  /// - a state field
  int bits;

  /// togglee item 0..61 (0..31) disable bit:   1:disabled 0:enabled.
  ///
  /// Note that class api operates in terms of "active", ie. on
  /// negation of _ds_ bits.
  /// - a state field
  int ds;

  /// radio-groups configuration mask, 1 marks a member of adjacent 1s group.
  /// - [rg] is a configuration field, usually set once.
  int rg;

  /// recently changed bits mask. 1s marks changed state bit at respective
  /// positions.  It represents _outgoing signals_ about recent changes done.
  /// _Never copied nor cloned_.
  ///
  /// Getters [changed] and [changedAt] are more convenient to use than direct
  /// read of `chb`.
  int chb;

  /// history hash keeps `serial` and `recent` values. Live Toggler updates `hh`
  /// on each state change. State copies have `hh` frozen at values origin had
  /// at copy creation time, even if they are being manipulated after.
  /// - hh is called a _status_ field
  ///
  /// Note: Whether `hh` should be serialized and restored depends on App's
  /// state management architecture used.
  int hh;

  /// handler `void after(TransientState fixState, Toggler current)`
  /// is called after state change has been _commited_. If not null, it is
  /// expected to deal also with after-change notifications. Especially ones
  /// that do not fit in the uniform `notifier` shape (eg. some _Model_ value
  /// can be fed to some _Stream_). If `after` is present it is also expected to
  /// pass current _chb_ to the _notifier_, in the very last line:
  /// `current.notifier?.pump(current.chb);`
  TogglerAfterChange? after;

  /// handles outgoing notifications with some concrete implementation of a
  /// ToggledNotifier class. If given, it will be _pumped_ with _chb_ after any
  /// change if _fix_ will return _true_, and if _fix_ did not marked new state
  /// as _done_.
  ///
  /// If both _notifier_ object and [after] handler are given, _notifier_ is
  /// **not** run automatically: if needed, you should _pump_ it from within
  /// your [after] handler yourself. Ie. your last line of [after] handler
  /// should say `current.notifier!.pump(current.chb);`
  ToggledNotifier? notifier;

  /// handler `bool fix(Toggler liveState, TransientState newState)`
  /// manages state transitions. Eg. enabling or disabling items if some
  /// condition is met, or testing and/or manipulating outer state of some
  /// _Model_ a [Toggler] instance reflects.
  ///
  /// _Fix_ fires either on a direct change request (eg. set1, clear, toggle),
  /// or on a _signal_ called by a reflected entity.
  ///
  /// Arguments:
  /// - `liveState` is a reference to _this_ toggler. It can be read, it may not
  /// be manipulated.
  /// - `newState` is a Toggler with added _signals_ api, that allow to extend
  /// state settling over more than one Toggler (or _Model_). NewState object
  /// will have its `.bits` and `.ds` updated with incoming _direct_ change,
  /// if `fix` runs due to some set. Or _newState_ will have non-zero `signals`
  /// property, if `fix` runs dua to a signal.  See also [TransientState] docs.
  /// If `fix` calls some _outer_ code that in turn sets or signals something back,
  /// these _outer_ changes will be seen on a _newState_ immediately, for `fix`
  /// to inspect, register, or revert.
  ///
  /// Any operations `fix` does on its `newState` argument and external operations
  /// that were reflected in the _newState_ will be seen as a next _live state_
  /// after `fix` returns _true_, ie. "commits" a new state.  On a _false_
  /// return changes will be abandoned. Note that _changes to the register_, not
  /// changes made to the reflected values, the less to the _outer_ state).
  ///
  /// - On a _state commit_ signals that came are merged with _newState_ register
  /// changes and both make to the _live state_ `chb` "changed bits" register, also
  /// called an "out signal".  Unless supressed or cleared using
  /// [TransientState] methods.  The `chb` finally may make to the [notifier].
  ///
  /// In simpler Apps `fix` state handler is the only place where business-logic
  /// is implemented and where Model state transitions occur.
  ///
  /// - If `fix` is null _signals_ are ignored, then any and every and each
  /// _direct change_ from a setter is commited immediately.
  /// - during the `fix` run registries as read from the _outside_ the `fix`
  /// handler are still in the stable ("fixed") state.  Any changes from the
  /// _outside_ can be seen only _inside_ the `fix`.
  TogglerStateFixer? fix;

  /// Toggler registers are public for easy tests and custom serialization.
  /// A Toggler instance with any state transition handler (`fix`, `after`,
  /// `notifier`) non null is said to be a _live_ one. If all state transition
  /// handlers are null, it is a _state copy_ Toggler object.
  /// - `bits` and `ds` together are the state register itself
  /// - `chb` (changed bits) property is an "out" signals register
  /// - `hh` (history hash) is an unique generational data (a number)
  /// - `rg` (radio groups) is a configuration usually set once
  Toggler({
    this.fix,
    this.after,
    this.notifier,
    this.bits = 0,
    this.ds = 0,
    this.hh = 0,
    this.rg = 0,
    this.chb = 0,
  });

  /// get copy of state (bits, ds, rg, hh), with flags, handlers and chb cleared.
  Toggler state() => Toggler(bits: bits, ds: ds, rg: rg, hh: hh & _fZero);

  /// live state Toggler may inform outer world, state copies have no means for
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool get _live => fix != null || notifier != null || after != null;

  /// _done_ flag can be set on a _live_ Toggler by an outer code. 'Done' always
  /// is cleared automatically on a state change, but is seen on the _liveState_
  /// by a `fix` handler.
  bool get done => hh & _fdone != 0;
  set done(bool e) => e ? hh |= _fdone : hh &= ~_fdone;

  /// sets done flag and always returns _true_.
  ///
  /// True-always return allows to mark ViewModel on the Flutter Widget _build_
  /// using `markDone() ? object : null,` constructs.  Eg. to notify yourself
  /// that some conditional build completed at an expected path.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool markDone() => (hh |= _fdone) != 0;

  /// Error flag is set if index was not in 0.._imax range.
  ///
  /// In _release_ code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken: cause in debug
  /// builds an assertion should threw right after setting the _error_ flag.
  bool get error => hh & _ferr != 0;
  set error(bool e) => e ? hh |= _ferr : hh &= ~_ferr;

  /// index of the most recent single change coming from a state setter
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int get recent => hh.toUnsigned(6);

  /// monotonic counter increased on each state change. In _state copies_
  /// `serial` is frozen at value origin had at copy creation time.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int get serial => hh >> 16;

  // /* methods */ /////////////////////////////////////////////////////////////
  /// _true_ if any bit in range, or as in mask is set. By default method tests
  /// the _bits_ property, but it can test any int, usually _ds_, or _chb_ member.
  /// Either query with _mask_ or _first..last_ range, not both.
  bool anyOfSet(
      {int? test,
      int rangeFirst = 0,
      int rangeLast = bIndexMax,
      int mask = 0}) {
    test ??= bits;
    assert(mask <= sMaskAll, 'Invalid mask $mask provided');
    if (mask != 0) return test & mask & sMaskAll != 0;
    int n = 1 << rangeFirst;
    while (rangeFirst < _hbi && rangeFirst <= rangeLast) {
      if (test & n != 0) return true;
      n <<= 1;
      rangeFirst++;
    }
    return false;
  }

  /// _true_ if Toggler item at _bIndex_ is enabled (has _ds_ bit = 0).
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool active(int bIndex) => ds & (1 << _v(bIndex)) == 0;

  /// _true_ if latest changes happened at _sMask_ set bit positions
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool changed([int sMask = sMaskAll]) => chb & sMask & sMaskAll != 0;

  /// _true_ if latest changes happened _at_ index
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool changedAt(int at) => chb & (1 << _v(at)) != 0;

  /// copy `bits` and `ds` to the `other` Toggler
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  copyStateTo(Toggler other) {
    other.bits = bits;
    other.ds = ds;
  }

  /// _true_ if state of `this` and `other` differs. Optionally just at positions
  /// provided with _mask_ (1), or within a given _first..last__ indice
  /// range. _sMask_ has higher priority than range, so either query with
  /// _sMask_ or with _first..last_, not both.
  ///
  /// Either range or mask allow eg. for ChangeNotifiers be distinct for
  /// different parts of a common to the App Toggler.
  bool differsFrom(Toggler other,
      {int bFirst = 0, int bLast = bIndexMax, int mask = 0}) {
    if (mask != 0) {
      assert(mask <= sMaskAll, 'Invalid mask $mask provided');
      mask = mask & sMaskAll;
      return bits & mask != other.bits & mask || ds & mask != other.ds & mask;
    }
    bFirst = _v(bFirst);
    bLast = _v(bLast);
    int p = bFirst;
    int n = 1 << bFirst;
    int d = bits ^ other.bits;
    while (p < _hbi && p <= bLast) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    p = bFirst;
    n = 1 << bFirst;
    d = ds ^ other.ds;
    while (p < _hbi && p <= bLast) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    return false;
  }

  /// enable item at _bIndex_.
  void enable(int bIndex) => setDS(bIndex, false);

  /// disable item at _bIndex_.
  void disable(int bIndex) => setDS(bIndex, true);

  /// _true_ if other copy has been created after us. A _live_ Toggler object
  /// (one with a handler and/or notifier) can never be older than a copy or
  /// other live Toggler.
  bool isOlderThan(Toggler other) => _live
      ? false
      : other._live
          ? true
          : hh >> 16 < other.hh >> 16;

  /// radioGroup declares a range of items that have "one of" behaviour.
  /// Ranges may not overlap nor even be adjacent. Ie. there must be at least
  /// one non-grouped item placed between two radio groups. Eg. ranges 0..3 and
  /// 5..7 (gap at 4) are OK but 0..3 and 4..6 are not (no 3 to 4 gap).
  /// Gap index is fully usable for an independent item.
  ///
  /// Allowed group boundaries are: `0 <= first < last <= bIndexMax`, if this
  /// condition is not met, or ranges touch or overlap, radioGroup will throw on
  /// debug build, or it will set error flag on _release_ build.
  ///
  /// A radioGroup creation does not run the state transition handlers, and it
  /// should not be performed from within the `fix` nor `after`. Any number of
  /// calls to radioGroup can be replaced by assigning a predefined constant to
  /// the `rg` member.
  ///
  /// Note that if a curently set item will be directly cleared it will make
  /// all in radio group being off. Same as on a real 100yo radio receiver.
  void radioGroup(int biFirst, int biLast) {
    biFirst = _v(biFirst);
    biLast = _v(biLast);
    assert(biFirst < biLast,
        'First item for RadioGroup configuration must be less than Last');
    var nrm = rg;
    var i = biFirst;
    var c = 1 << (biFirst - (i == 0 ? 0 : 1));
    bool overlap() {
      if (rg & c != 0) {
        error = true;
        assert(false,
            'Radio ranges may NOT overlap nor be adjacent to each other [$biFirst..$biLast])');
        return true;
      }
      return false;
    }

    if (overlap()) return; // i-1
    if (i > 0) c <<= 1;
    while (true) {
      if (overlap()) return; // i
      if (i > biLast) break;
      nrm |= c;
      c <<= 1;
      i++;
    }
    rg = nrm;
  }

  /// clear (to _0_, _off_, _false_) item bit at _bIndex_.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item bit will be cleared only if item is active.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void set0(int bIndex, {bool ifActive = false}) =>
      _set(bIndex, ifActive, false);

  /// set (_1_, _on_, _true_) item at _bIndex_.  By default state changes are
  /// unconditional, but an optional argument `ifActive: true` mandates prior
  /// _active_ check. Ie. item will be set only if it is active.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void set1(int bIndex, {bool ifActive = false}) =>
      _set(bIndex, ifActive, true);

  /// state bit setter
  void _set(int bIndex, bool ifActive, bool to1) {
    assert(() {
      if (_tranS != null && _tranS!.held) {
        signal(0); // do not repeat fuse message
      }
      return true;
    }(), '');
    bIndex = _v(bIndex);
    if (ifActive && !active(bIndex)) return;
    int ntg =
        _tranS != null ? _tranS!.bits & ~(1 << bIndex) : bits & ~(1 << bIndex);
    if (to1) {
      if (rg & (1 << bIndex) != 0) {
        // clear all in this radio group
        int k = bIndex;
        int n = 1 << bIndex;
        while (k < _hbi && rg & n != 0) {
          ntg &= ~n;
          n <<= 1;
          k++;
        }
        k = bIndex;
        n = 1 << bIndex;
        while (k >= 0 && rg & n != 0) {
          ntg &= ~n;
          n >>= 1;
          k--;
        }
      }
      ntg |= 1 << bIndex;
    }
    _tranS != null
        ? _tranS!.bits = ntg
        : ntg != bits
            ? _live
                ? _verto(bIndex, ntg, false, to1)
                : bits = ntg
            : null;
  }

  /// disable (true) or enable (false) an item at index _bIndex_.
  ///
  /// Note that _ds_ property has bit set to 1 for _disabled_ items.
  void setDS(int bIndex, bool disable) {
    assert(() {
      if (_tranS != null && _tranS!.held) {
        signal(0); // do not repeat fuse message
      }
      return true;
    }(), '');
    bIndex = _v(bIndex);
    int nds = ds;
    disable ? nds |= 1 << _v(bIndex) : nds &= ~(1 << _v(bIndex));
    _tranS != null
        ? _tranS!.ds = nds
        : nds != ds
            ? _live
                ? _verto(bIndex, nds, true, disable)
                : ds = nds
            : null;
  } // xTODO setDS

  /// sets item state at _bIndex_ to the given _state_ value.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie.  item will change state only if it is active.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void setTo(int bIndex, bool state, {bool ifActive = false}) =>
      _set(bIndex, ifActive, state);

  /// changes item at _bIndex_ to the opposite state.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will change state only if it is active.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void toggle(int bIndex, {bool ifActive = false}) =>
      _set(bIndex, ifActive, bits & (1 << _v(bIndex)) == 0);

  /// Verify index. On fail returns 0 and sets error in _release_ build
  /// if verification failed. Throws in _debug_ build.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int _v(int bIndex) {
    if (bIndex < _hbi && bIndex >= 0) return bIndex;
    error = true;
    assert(bIndex < _hbi && bIndex >= 0, 'Bit index ($bIndex) out of range!');
    return 0;
  }

  /// true if state stabilized, false if fix/after/notifier still run
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool get isFixed => _tranS == null;

  // returns item at sIndex state as 0..3 int of b1:ds b0:tg
  // for use with `switch`.
  // int numAt(int sIndex) => (ds >> sIndex) << 1 | bits >> sIndex;

  // =========================== Signal api ===============================
  // TransientState is a state copy (externally mutable) for the `fix` run.
  TransientState? _trs; // instance
  TransientState? _tranS; // in use

  /// signal some change at `bIndex`. A noop if there is no `fix` handler attached.
  /// Except for first (aka firing) signal, any number of others coming at the
  /// same _bIndex_ will register only once.
  ///
  /// - `tag` number can be read from _tranState.signalTag_. It must fit in 32b uint.
  /// Only _firing_ signal tag is preserved.
  void signal(int bIndex, {int tag = 0}) {
    // xTODO signal
    assert(_tranS == null || !_tranS!.held, '''
  Synchronous set or signal came from a distant place on "after" or "notifier" run.

  Usually it means that an other fixer changes or signalls us back while acting
  on notify it got from us.  Such behavior might make for an endless loop so we
  break early.

  In release build such set or signal will be silently ignored.

  ''');
    assert(tag < 1 << 32, 'Signal tag must fit into 32 bits number');
    if (fix == null) return;
    _tranS != null
        ? _tranS!.signals |= 1 << _v(bIndex)
        : _verto(_v(bIndex), tag, false, true, true);
  }

  /// set semaphore forebading any changes to the live state.
  /// Not to be called in `fix` or `after`;
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void hold() {
    assert(_live, 'hold may be called only on a live state Toggler');
    assert(_tranS == null, 'hold may not be called during the fix run');
    _live && _tranS == null ? hh |= _fheld : null;
  }

  /// true if state changes are on hold
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool get held => hh & _fheld != 0;

  /// allow changes to the live state (cancel a former hold).
  /// Not to be called in `fix` or `after`;
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void resume() {
    assert(_tranS == null, 'resume called during the `fix` run');
    hh &= ~_fheld; // XXX darts ~ makes negative
    assert(hh >= 0, "George Boole's poltergeist is kicking our highest bit");
  }

  /// not registering setter for disable bits, for use from user `fix` code
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void fixDS(int bIndex, bool to) =>
      to ? ds |= (1 << _v(bIndex)) : ds &= ~(1 << _v(bIndex));

  /// not registering setter for state bits, for use from user `fix` code
  ///
  /// Note that non registering setter is not radio-group aware. Ie. calling
  /// this may set more than one bit on a radio-group.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void fixBits(int bIndex, bool to) =>
      to ? bits |= (1 << _v(bIndex)) : bits &= ~(1 << _v(bIndex));

  /// _true_ if Toggler item at _index_ is set (`tg` item bit is 1).
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool operator [](int bIndex) => bits & (1 << _v(bIndex)) != 0;

  /// unconditionally set value of item at index _bIndex_.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void operator []=(int bIndex, bool v) => _set(bIndex, false, v);

  /// Toggler state transition engine.
  ///
  /// - nEW has new value for `bits` or `ds`; or signal's Tag,
  /// - isDs tells that _ds_ has changed; otherwise _bits_;
  /// - to1 tells change direction;
  /// - isSig is true on signal.
  // xTODO verto
  void _verto(int bIndex, int nEW, bool isDs, bool to1, [bool isSig = false]) {
    if (_tranS != null || hh & _fheld != 0) return; // live but on hold
    final nhh = (((hh >> 16) + 1) << 16) | // serial++, flags b15..b9
        ((isSig ? (1 << 8) : 0) | //   b8: by a signal,   ca9  b8..b0
            (isDs ? (1 << 7) : 0) | // b7: tg/ds
            (to1 ? (1 << 6) : 0) | //  b6: to0/to1
            bIndex); //            b5..b0: item index
    // singleton transient state
    _trs ??= TransientState();
    if (isSig) {
      _trs!.bits = bits;
      _trs!.ds = ds;
      _trs!.hh = (nEW << 16 | (nhh & 0x1ff)); // tag
      _trs!.chb = 0;
    } else {
      _trs!.bits = isDs ? bits : nEW;
      _trs!.ds = isDs ? nEW : ds;
      _trs!.hh = nhh & 0x1ff; // tag zero
      _trs!.chb = isDs ? ds ^ nEW : bits ^ nEW;
    }
    _trs!.signals = 0;
    _trs!.supress = 0;
    _trs!.rg = rg;
    _tranS = _trs;
    final tranS = _tranS!;
    if (fix != null) {
      tranS.signals = isSig ? 1 << bIndex : 0; // mark if on signal
      if (fix!(this, tranS)) {
        // (      got signals |  old->new changes )   & clamp   & ~clearSignal
        chb = ((tranS.signals | (bits ^ tranS.bits) | (ds ^ tranS.ds)) &
            sMaskAll &
            ~tranS.supress);
        bits = tranS.bits; // commit state
        ds = tranS.ds; // commit state
      }
    } else {
      chb = isDs ? ds ^ nEW : bits ^ nEW;
      isDs ? ds = nEW : bits = nEW;
    }
    hh = nhh; // new serial, zero flags
    tranS.hh |= _fheld; // to catch late signals during after and notify phases
    if (tranS.hh & _finish != 0) {
    } else if (after != null) {
      after!(tranS, this);
    } else if (notifier != null) {
      notifier!.pump(chb);
    }
    _tranS = null; // state fixed, resume
  }
} // class Toggler

/// Volatile object passed to `fix` and `after` handlers.
///
/// At the `fix` beginning it exposes snapshot of the _live state_ `bits` and `ds`,
/// along with _signals_ that may have fired the state transition.  On the `fix`
/// run this object will register effects of this `fix` handler making changes
/// (eg. _Model_ internals that usually _set_ or _clear_ bits, or externals
/// entities that usually _signals_ back).  This mechanics provides running
/// `fix` with a feedback about changes it initiated without risking accidental
/// recurrent loops.
///
/// Signals that came during a fix round are automatically passed on to the _live
/// state_ `chb` (unless supressed or `signals` zeroed). State (`bits`, `ds`)
/// changes can be applied to the `newState` argument of `fix` using
/// [copyStateTo] method.
///
/// It can be read like its ancestor Toggler.
/// , but its state may not be modified
/// internally (from `fix`). It **will** be modified externally, if your `fix`
/// called something
/// [TransientState] adds to Toggler a _signal_
/// manipulation api, allowing to inspect signals that may come during a `fix`
/// round and modify or supress "out" signals that will be passed to `after`
/// then to `notifier` once `fix` ends.
///
/// _Beware! a bloat of foolproofing checks was removed, so you certainly now MAY
/// make troubles for yourself eg. by assigning TransientState object a `fix` or
/// `notifier`, or side-modifying state through a reference.  Do not do that!_.
class TransientState extends Toggler {
  // TransientState({ super.bits, super.ds, super.rg, super.hh, super.chb, });

  /// Non-zero if `fix` ran on a signal, or if signals came during a `fix`
  /// run. Has 1 at signalled bIndex position(s).
  ///
  /// May change during the `fix` run, if `fix` modifies something external that
  /// in turn signals back.  Registers first and then any number of signals coming
  /// to the same index.
  int signals = 0;

  /// outgoing singnals mask (1 masked, ie. signal will be cancelled).
  int supress = 0;

  /// A tag that was passed with a firing signal.
  ///
  /// Subsequent signals may not register their tags directly. If needed such
  /// feature can be added to a _Model_ with a few lines wrapper and a List.
  /// _Read also [signal] docs_.
  ///
  /// As any other signal-related data this can be read (can be non-zero) only
  /// in the body of the `fix` handler on its _fixState_ parameter.
  /// Otherwise always 0.  An assert is added to curb misuse early.
  ///
  /// - _To be used only on an _fixState_ argument within a `fix` handler_
  int get signalTag => hh >> 16;

  /// [TransientState] serial is always 0. The _live state_ [serial] is always
  /// one less than serial of the `newState` argument.
  @override
  int get serial => 0;

  /// supress outgoing signal (ones of _live state_ chb) by index.  All can be
  /// supressed by `supress = sMaskAll;`
  void supressOutAt(int bIndex) => supress |= 1 << _v(bIndex);

  /// clear incoming signals by index. All can be cancelled by `signals = 0;`.
  void clearComingAt(int bIndex) => signals &= ~(1 << _v(bIndex));

  /// commit but do not inform the _outer world_ (eg. if all changes are internal)
  void skipAfterAndNotify() => hh |= _finish;

  /// forcefully fixes _bIndex_ "changed" signal, regardless of its
  /// source (be it external signal or sets made during `fix` run).
  /// Commited _live state_ `chb` will then have 1 or 0 at bIndex position,
  /// respective of `to` argument being true(1) or false(0).
  ///
  /// incoming signals can be cleared by mask with [clearComingAt],
  /// outgoing signals can be supressed by mask with [supressOutAt];
  void fixOutSignal(int bIndex, bool to) {
    bIndex = _v(bIndex);
    if (to) {
      signals |= (1 << bIndex);
      supress &= ~(1 << bIndex);
    } else {
      supress |= (1 << bIndex);
    }
  }
}

/// `fix` function signature
typedef TogglerStateFixer = bool Function(
    Toggler liveState, TransientState newState);

/// `after` function signature
typedef TogglerAfterChange = void Function(
    TransientState commitedState, Toggler current);

// coverage:ignore-start
/// Toggler's change notification dispatcher, an abstract interface.
/// Concrete implementation can be found eg. in `package:uimodel/uimodel.dart`
abstract class ToggledNotifier {
  /// the _chb_ recent changes bitmask is to be pumped here.
  /// Automatically, if an implementation is provided to Toggler _notifier_.
  void pump(int chb);

  /// implementations may inform about how many points observe
  int get observers => -1;

  /// deregistering and cleanup code should go to `detachSelf`
  /// It is expected that it is the Notifier having the most knowledge who
  /// is listening.
  void detachSelf() {}
}

/// positive integer to hex string with leading zeros, fixed width 'len'
// ignore: unused_element
String _ph(int n, [int len = 8]) => _pd(n, len, 16);

/// positive integer to decimal string with leading zeros, fixed width 'len'
String _pd(int n, [int len = 2, int radix = 10]) {
  const zc = '00000000000000000000000000000000';
  final zs = (len < zc.length) ? zc.substring(0, len) : zc;
  final nb = n.toRadixString(radix);
  return (nb.length > len)
      ? nb.substring(nb.length - len, nb.length)
      : zs.substring(0, zs.length - nb.length) + nb;
}
// coverage:ignore-end
