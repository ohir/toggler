// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

/// Toggler library is a state machine register that can be used as basis for
/// Models and ViewModels of **MVVM** and similar architectures.  While it was
/// designed for use in singleton aka "ambient" Models, it also may support
/// _reactive_ architectures via its `state` and `clone` copying constructors.
///
/// Toggler supports pre-commit state validation and mutation. After any single
/// change it first fires `fix` state transition handler, then commits new state
/// `fix` just prepared, then calls `after` or signals `notifier` to inform
/// outer world of changes made. This way Toggler implements a classic MVVM and
/// similar newer architectures unidirectional flow of state changes.
///
/// Toggler is small, fast, and it has no dependecies.
///
/// Test coverage: **100.0%** (192 of 192 lines)
library toggler;

const _bits = 53; // 53:web 64:noWeb // dart2js int is 53 bit

///   (52) flag bit index
const _bf = _bits - 1; //
/// (51) item max index bit
const _imax = _bits - 2; //
/// selects all state bits 0..51, a sMask trimmer
const _mAll = (1 << _bf) - 1; //

/// Last usable bit index. While it could be 62, it is now 51 to enable web use.
/// If you need no web and really need 10 more flags you may use source package
/// and update `_bits = 53;` to `_bits = 64;`.
const bIndexMax = _imax;

/// this mask selects all state bits (indice).
const sMaskAll = _mAll;

/// Toggler class keeps state of up to 52 boolean values (bits, items) that can
/// be manipulated one by one or in concert.
///
/// For ViewModels use, an independent _disabled_ flag is avaliable for every
/// state bit, then _radio group_ behaviour can be declared on up to 17 separated
/// groups of items.  Each state bit value can be retrieved and set using
/// index[] operator, usually with a constant symbolic name.
///
/// By convention Toggler const index name has a `b` (bit index) name prefix,
/// then respective const bitmask uses `s` (select mask) prefix. Eg.
/// `const bPrize = 33; const sPrize = 1 << bPrize;`
///
/// _In package's tool/ directory there is a script that generates stub
/// constants together with their masks, for library user to rename later_.
class Toggler {
  /// togglee item 0..51 value bit:     1:set 0:cleared.
  /// - a state field
  int bits;

  /// togglee item 0..51 disable bit:   1:disabled 0:enabled.
  ///
  /// Note that class api operates in terms of "active", ie. on
  /// negation of _ds_ bits.
  /// - a state field
  int ds;

  /// radio-groups 0..51 (mask):        1:member of adjacent 1s group.
  /// - a config field
  int rg;

  /// recently changed at 0..51 (bits): 1:at this bit index.
  /// - a signal field. Volatile state:  neither copied nor cloned.
  ///
  /// XXX changed bits indicator tells indice of all state changes, both in _bits_,
  /// _ds_, and/or of some external entity observed by a Toggler instance.
  ///
  /// XXX in `fix` code, then after `fix` _chb_ will be updated to reflect **all**
  /// changed indice, including ones changed by `fix`. Use _changed_ method to
  /// access _chb_ in a readable way.
  int chb;

  /// history hash keeps `serial` and `recent` values.  Live Toggler updates
  /// `hh` on each state change. State copies have `hh` frozen at values origin
  /// had at copy creation time, even if they are being manipulated after.
  /// - a status field
  ///
  /// Note: Whether `hh` should be serialized and restored depends on App's
  /// state management architecture used. Keep in mind that MSb of `hh` holds a
  /// `hold` flag used by time-travelling extensions like _TogglerReplay_ so
  /// this bit should never be restored to 1. Omit it with eg.
  /// `ntog.hh = stored.hh.toUnsigned(bIndexMax);`
  int hh;

  /// handler `void after(Toggler oldState, Toggler current)`
  /// is called after state change has been _commited_. If not null, it is
  /// expected to deal also with after-change notifications. Especially ones
  /// that do not fit in the uniform `notifier` shape (eg. some Model value can
  /// be fed to some _Stream_). If `after` is present it is also expected to
  /// pass current _chb_ to the _notifier_ in the very last line:
  /// `current.notifier?.pump(current.chb);`
  TogglerAfterChange? after;

  /// Concrete implementation of a ToggledNotifier class. If given, it will be
  /// _pumped_ with _chb_ after any change if _fix_ will return _true_, and if
  /// _fix_ did not marked new state as _done_.
  ///
  /// If both _notifier_ object and _after_ handler are given, _notifier_ is
  /// **not** run automatically: if needed, you should _pump_ it from within
  /// your _after_ handler yourself. Ie. your last line of _after_ handler
  /// should say `current.notifier!.pump(current.chb);`
  ///
  ///
  ToggledNotifier? notifier;

  /// handler `bool fix(Toggler oldState, Toggler newState)`
  /// manages state transitions. Eg. enabling or disabling items if some
  /// condition is met, or testing and/or manipulating outer state a [Toggler]
  /// instance reflects.
  ///
  /// Arguments:
  /// - `oldState` has `.bits` and `.ds` copied from the _live_ state.  Its `chb`
  /// has 1 set at bIndex of signal, if `fix` runs due to signal, 0 otherwise.
  /// - `newState` has `.bits` and `.ds` copied from the _live_ state then coming
  /// change, if any, applied.  Its `serial` is also already updated.  Its `chb`
  /// has 1 set at bIndex of change, if `fix` runs due to external change made
  /// by setter (eg. clear, toggle), 0 otherwise.
  ///
  /// Any operations `fix` does on its `newState` argument will be seen as a
  /// next _live state_ after `fix` returns (true).  The `oldState` argument
  /// provides `fix` with a view into the live state. It also allows `fix` to
  /// read incoming, and set or supress outgoing, change _signals_.
  ///
  /// _Fix_ fires either on a direct change request (eg. set1, clear, toggle),
  /// or on a _signal_ called by a reflected entity.  Direct changes to the
  /// _live_ state may not happen during the `fix` run, signals may. Any signal
  /// that come during `fix` run can be read immediately via `oldState': `chb`,
  /// `changes([sMask])`, or `changesAt([bIndex])` of the _oldState_.
  ///
  ///
  /// At `fix` call:
  /// - `oldState.bits` and `oldState.ds` are copied from the _live_ object. Other
  /// `oldState` fields are of internal use (explained below).
  /// - `newState` is-a state copy of the _live_ object with direct change
  /// already applied, if any came. This object can be manipulated in `fix` then
  /// it will be commited to the _live state_ (on `fix` returning _true_).
  /// - `newState.changedBits` reflects a direct change, if any came.  It will be
  /// zero if `fix` was called via _signal_.  During `fix` run it may change as
  /// `fix` code changes its `newState` argument.
  /// - `oldState.signalBits` reflects a signal, if any came. It will be zero if
  /// `fix` was called for a direct change (eg. set1 or disable).  If `fix`
  /// manipulates external entities that _signal_ back, such signal will be
  /// reflected at `oldState.signalBits` immediately. Ie. signals can be tested
  /// during a `fix` run.
  /// - On a state commit later, signalBits are merged (ORed) to the _live_ state
  /// `chb`, unless supressed or cleared.
  /// - `oldState.clearSignal(bIndex)` resets outgoing change bit. So outer world
  /// may not learn that some internal state changed.
  ///
  /// On `fix` _true_ return, _newState_ will be commited, ie. copied to the
  /// live Toggler object in a single run.  Then either `notifier` will be
  /// _pumped_ with `chb` change bits, or the `after` handler will run. If
  /// either is present and unless supressed.  If `fix` returns _false_ changes
  /// to the state register are abandoned.
  ///
  /// A `fix` code may suppress subsequent `notifier` or `after` call by setting
  /// _done_ flag on a _newState_. This internal _done_ state is not copied to
  /// the live Toggler on commit.
  ///
  /// In simpler Apps `fix` state handler is the only place where business-logic
  /// is implemented and where Model state transitions occur.
  ///
  /// If `fix` is null _signals_ are ignored and every and each direct change
  /// from a setter is commited immediately.
  TogglerStateFixer? fix;

  /// All Toggler members are public for easy tests and custom serialization.
  /// A Toggler instance with any state transition handler (`fix`, `after`,
  /// `notifier`) non null is said to be a _live_ one. If all state transition
  /// handlers are null, it is a _state copy_ Toggler object.
  /// - `bits` and `ds` together are the state register
  /// - `chb` (changed bits) is a change signal register
  /// - `hh` (history hash) is an unique generational data (number)
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
  }) {
    // clear internal flags, if set
    // rg &= _mSBi; rg is now exposed in signal api, can't bear a flag
    hh &= _mAll; // done
    ds &= _mAll; // hold
    bits &= _mAll; // error
  }

  /// live state Toggler may inform outer world, state copies have no means for
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool get _live => fix != null || notifier != null || after != null;

  /// _done_ flag can be set on a _live_ Toggler by an outer code. 'Done' always
  /// is cleared automatically on a state change.
  ///
  /// Both `fix` and `after` handlers may test _oldState_ whether _done_ was
  /// set.  The `fix` handler may also set _done_ on a _newState_ to suppress
  /// subsequent _after_ and _notifier_ run. (_done_ set by `fix` is internal
  /// only, it does not make to the commited new state).
  ///
  /// In _reactive_ settings _done_ flag can be set on a state clone to mark it
  /// as "being spent". Note that _done_ flag __always__ comes cleared on all new
  /// copies and clones - whether made of live object or of a state copy.
  bool get done => hh & 1 << _bf != 0;
  set done(bool e) => e ? hh |= 1 << _bf : hh = hh.toUnsigned(_imax);

  /// Error flag is set if index was not in 0.._imax range.
  ///
  /// In release code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken: as in debug
  /// builds an assertion should threw right after setting _error_.
  bool get error => bits & 1 << _bf != 0;
  set error(bool e) => e ? bits |= 1 << _bf : bits = bits.toUnsigned(_imax);

  /// index of the most recent single change coming from a state setter
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int get recent => hh.toUnsigned(6);

  /// monotonic counter increased on each state change. In _state copies_
  /// `serial` is frozen at value origin had at copy creation time.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int get serial => hh.toUnsigned(_bf) >> 16;

  // /* methods */ /////////////////////////////////////////////////////////////
  /// _true_ if any bit in range, or as in mask is set. By default method tests
  /// the _bits_ property, but it can test any int, usually _ds_, or _chb_ member.
  /// Either query with _mask_ or _first..last_ range, not both.
  bool anyOfSet(
      {int? test, int rangeFirst = 0, int rangeLast = _imax, int mask = 0}) {
    test ??= bits;
    if (mask != 0) return test & vma(mask) != 0;
    int n = 1 << rangeFirst;
    while (rangeFirst < _bf && rangeFirst <= rangeLast) {
      if (test & n != 0) return true;
      n <<= 1;
      rangeFirst++;
    }
    return false;
  }

  /// _true_ if Toggler item at _bIndex_ is enabled (has _ds_ bit 0).
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool active(int bIndex) => ds & (1 << v(bIndex)) == 0;

  /// _true_ if latest changes happened at _sMask_ set bit positions
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool changed([int sMask = sMaskAll]) => chb & vma(sMask) != 0;

  /// _true_ if latest changes happened _at_ index
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool changedAt(int at) => chb & (1 << v(at)) != 0;

  /// clear (to _0_, _off_, _false_ state) item at _bIndex_.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will be cleared only if it is active.
  ///
  /// Note that _clear_ does not know about radio groups by itself
  /// so _clear_ of an active radio member will make all in group being off.
  void clear(int bIndex, {bool ifActive = false}) {
    bIndex = v(bIndex);
    if (ifActive && !active(bIndex)) return;
    int ntg = bits;
    ntg &= ~(1 << bIndex);
    if (ntg != bits) verto(bIndex, ntg, false, false);
  }

  /// returns a deep copy of the Toggler state, including `after`, `notifier`,
  /// and `fix` references; Flags (done, error) are cleared. Volatile `chb` is 0.
  Toggler clone() => Toggler(
      notifier: notifier,
      after: after,
      fix: fix,
      bits: bits,
      ds: ds,
      rg: rg,
      hh: hh);

  /// _true_ if state of `this` and `other` differs. Optionally just at positions
  /// provided with _mask_ (1), or within a given _first..last__ indice
  /// range. _sMask_ has higher priority than range, so either query with
  /// _sMask_ or with _first..last_, not both.
  ///
  /// Both range and onlyMask allow eg. for ChangeNotifiers be distinct for
  /// different parts of a common to the App Toggler.
  bool differsFrom(Toggler other,
      {int bFirst = 0, int bLast = _imax, int mask = 0}) {
    if (mask != 0) {
      mask = vma(mask);
      return bits & mask != other.bits & mask || ds & mask != other.ds & mask;
    }
    bFirst = v(bFirst);
    bLast = v(bLast);
    int p = bFirst;
    int n = 1 << bFirst;
    int d = bits ^ other.bits;
    while (p < _bf && p <= bLast) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    p = bFirst;
    n = 1 << bFirst;
    d = ds ^ other.ds;
    while (p < _bf && p <= bLast) {
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
          : hh.toUnsigned(_imax) >> 16 < other.hh.toUnsigned(_imax) >> 16;

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
  /// A radioGroup creation does not `after`. Any number of calls to radioGroup
  /// can be replaced by assigning a predefined constant to the `rm` member.
  ///
  /// Note that if a curently set item will be directly cleared it will make
  /// all in radio group being off.
  void radioGroup(int biFirst, int biLast) {
    biFirst = v(biFirst);
    biLast = v(biLast);
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

  /// set (_1_, _on_, _true_) item at _bIndex_.  By default state changes are
  /// unconditional, but an optional argument `ifActive: true` mandates prior
  /// _active_ check. Ie. item will be set only if it is active.
  void set1(int bIndex, {bool ifActive = false}) {
    bIndex = v(bIndex);
    if (ifActive && !active(bIndex)) return;
    int ntg = bits;
    if (rg & (1 << bIndex) != 0) {
      // clear all in this radio group
      int k = bIndex;
      int n = 1 << bIndex;
      while (k < _bf && rg & n != 0) {
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
    if (ntg != bits) verto(bIndex, ntg, false, true);
  }

  /// sets done flag and always returns _true_.
  ///
  /// True-always return allows to mark ViewModel on the Flutter Widget _build_
  /// using `markDone() ? object : null,` constructs.  Eg. to notify yourself
  /// that some conditional build completed at an expected path.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool markDone() => (hh |= 1 << _bf) != 0;

  /// disable (true) or enable (false) an item at index _bIndex_.
  ///
  /// Note that _ds_ property has bit set to 1 for _disabled_ items.
  void setDS(int bIndex, bool disable) {
    int nds = ds;
    disable ? nds |= 1 << v(bIndex) : nds &= ~(1 << v(bIndex));
    if (nds != ds) verto(bIndex, nds, true, disable);
  }

  /// sets item state at _bIndex_ to the given _state_ value.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie.  item will change state only if it is active.
  void setTo(int bIndex, bool state, {bool ifActive = false}) {
    state
        ? set1(bIndex, ifActive: ifActive)
        : clear(bIndex, ifActive: ifActive);
  }

  /// get copy of state, with flags, handlers and chb cleared.
  Toggler state() => Toggler(bits: bits, ds: ds, rg: rg, hh: hh);

  /// changes item at _bIndex_ to the opposite state.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will change state only if it is active.
  void toggle(int bIndex, {bool ifActive = false}) {
    bIndex = v(bIndex);
    if (ifActive && !active(bIndex)) return;
    if (bits & (1 << bIndex) != 0) {
      int ntg = bits;
      ntg &= ~(1 << bIndex);
      if (ntg != bits) verto(bIndex, ntg, false, false);
    } else {
      set1(bIndex);
    }
  }

  /// verify index, returns zero and sets error in _release_ build if
  /// verification failed. Throws on error in _debug_ build.
  int v(int bIndex) {
    assert(
        bIndex < _bf && bIndex >= 0, 'Toggler index ($bIndex) out of range!');
    if (bIndex < _bf && bIndex > 0) return bIndex;
    error = true;
    return 0;
  }

  /// Trim mask. Subclasses may also verify it.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int vma(int mask, {int trim = _mAll}) => mask & trim;

  /// true if state stabilized, false on the fix run
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool get fixed => _oldS == null;

  // =========================== Signal api ===============================
  /// keeps oldState state copy for the `fix` run.
  /// - `chb` keeps a firing signal, and subsequent signals coming on the `fix` run
  /// - `rg` keeps an exit signal supress mask
  /// - state copy is internally 'held' for identification purposes
  Toggler? _oldS;

  /// signal some change at `bIndex`. A noop if there is no `fix` handler attached;
  void signal(int bIndex) {
    if (fix == null) return;
    _oldS != null
        ? _oldS!.chb |= 1 << v(bIndex)
        : verto(0, 0, false, false, sigm: 1 << v(bIndex));
  }

  /// Non-zero mask if `fix` ran on a signal, or if signals came within a `fix`
  /// run, with 1s at signalled bIndex position.  May change during the `fix`
  /// run, if `fix` modifies something external that in turn signals back.
  /// - _To be used only on an _oldState_ argument within a `fix` handler_
  ///
  /// Getter throws on assert in _debug_ builds if used out of context.
  /// In _release_ builds it just returns 0.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int get signalsComing {
    assert(
        held && !_live, // normally held can't enter fix. Copy can't be on hold.
        'signalBits may read only on the oldState argument of the fix handler');
    return held && !_live ? chb : 0;
  }

  /// convenience getter of `chb` "changed bits" property
  int get xchangedBits => chb;

  /// forcefully fixes _bIndex_ "changed" signal, regardless of its source
  /// (external or made during `fix`).  After `fix` handler returns, commited
  /// _live state_ `chb` will have 1 or 0 at bIndex position, respective of `to`
  /// argument being true(1) or false(0).
  /// - _To be called only from `fix` and only on its `oldState` argument_.
  ///
  /// Hint: all incoming signals can be cleared using `oldState.chb = 0`, all
  /// outgoing signals can be supressed with `oldState.rg = sMaskAll`;
  ///
  /// Method throws on assert in _debug_ builds if used out of context.
  void fixSignal(int bIndex, bool to) {
    assert(
        held && !_live, // normally held can't enter fix. Copy can't be on hold.
        'fixSignal may be used only on the oldState argument of the fix handler');
    if (!held || _live) return;
    if (to) {
      chb |= 1 << v(bIndex);
      rg &= ~(1 << v(bIndex));
    } else {
      rg |= 1 << v(bIndex);
    }
  }

  /// set semaphore forebading any changes to the live state.
  /// Not to be called in `fix` or `after`;
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void hold() {
    assert(_live, 'hold may be called only on a live state Toggler');
    assert(_oldS == null, 'hold may not be called during the fix run');
    _live && _oldS == null ? ds |= 1 << _bf : null;
  }

  /// true if state changes are on hold
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool get held => ds & (1 << _bf) != 0;

  /// allow changes to the live state (cancel a former hold).
  /// Not to be called in `fix` or `after`;
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void resume() {
    assert(_oldS == null, 'resume called during the `fix` run');
    ds &= _mAll;
  }

  /// not registering setter for disable bits, for use from user `fix` code
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void fixDS(int bIndex, bool to) =>
      to ? ds |= (1 << bIndex) : ds &= ~(1 << bIndex);

  /// not registering setter for state bits, for use from user `fix` code
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void fixBits(int bIndex, bool to) =>
      to ? bits |= (1 << bIndex) : bits &= ~(1 << bIndex);

  /// _true_ if Toggler item at _index_ is set (`tg` item bit is 1).
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool operator [](int bIndex) => bits & (1 << v(bIndex)) != 0;

  /// unconditionally set value of item at index _bIndex_.
  void operator []=(int bIndex, bool v) => setTo(bIndex, v);

  /// Toggler state change engine.  For legitimate use of `verto` see `replay(cas)`
  /// method in examples TogglerReplay extension. (_Verto means 'to turn' in
  /// Latin_).
  ///
  /// - nEW is a new value for `bits` or `ds`
  /// - isDs tells that disable state has changed (preserved in cabyte)
  /// - actSet tells the action (preserved in cabyte)
  void verto(int i, int nEW, bool isDs, bool actSet, {int sigm = 0}) {
    if (!_live) {
      if (sigm != 0) return; // signal is meaningless on copy
      chb = isDs ? ds ^ nEW : bits ^ nEW; // pass coming single change bit
      isDs ? ds = nEW : bits = nEW;
      return;
    }
    assert(_oldS == null,
        '''State bit value may not be set from within running fix method.
  Only signals are allowed during fix run.

  Debug hint: this might even be set from a far away code of a distant fixer that
  fired after _this_ fix changed some other Toggler (eg. underlying other Model).
''');
    if (_oldS != null || ds & (1 << _bf) != 0) return; // live but on hold
    final nhh = (((hh.toUnsigned(_imax) >> 16) + 1) << 16) | // serial++
        ((hh.toUnsigned(16) & 0xff00) | //  b15..b8: extensions reserved
            (isDs ? (1 << 7) : 0) | //    cabyte b7: tg/ds
            (actSet ? (1 << 6) : 0) | //         b6: clear/set
            i.toUnsigned(6)); //             b5..b0: item index
    final oldS = state();
    if (fix != null) {
      oldS.ds |= 1 << _bf; // mark held
      oldS.rg = 0; // clearSignal mask
      oldS.chb = sigm; // if on signal
      _oldS = oldS;
      if (done) oldS.markDone(); // fix and after should know
      final newS = Toggler(
          bits: isDs ? bits : nEW, ds: isDs ? nEW : ds, rg: rg, hh: nhh);
      newS.chb = isDs ? ds ^ nEW : bits ^ nEW; // pass coming single change bit
      if (fix!(oldS, newS)) {
        // how it possibly could happen now?. Only if user code manipulated hh.
        assert(hh & _mAll == oldS.hh & _mAll, 'State data race detected!');
        bits = newS.bits;
        ds = newS.ds; // held no longer
        hh = newS.hh; // may come with 'done' flag set by fix
        rg = newS.rg; //
        // (incoming signals | computed changes) & clamp & ~clearSignal
        chb = ((oldS.chb | (bits ^ oldS.bits) | (ds ^ oldS.ds)) &
            _mAll &
            ~oldS.rg);
        /*/
        print('  ored: chbO ${oldS.chb}|${bits ^ oldS.bits}|${ds ^ oldS.ds}');
        print('   and: chbN ${_ph(~newS.chb & _mSBi)} & ${_ph(_mSBi)}');
        print('  chbs: chbO ${_ph(oldS.chb)} : chbN ${_ph(newS.chb)}');
        */
      }
    } else {
      hh = nhh; // new serial
      chb = isDs ? ds ^ nEW : bits ^ nEW;
      isDs ? ds = nEW : bits = nEW;
    }
    _oldS = null; // resume
    if (after != null) {
      done ? hh &= _mAll : after!(oldS, this);
    } else if (notifier != null) {
      done ? hh &= _mAll : notifier!.pump(chb);
    }
  }
  // bool get rsv => ds & 1 << _bf != 0;
  // set rsv(bool e) => e ? ds |= 1 << _bf : ds = ds.toUnsigned(_imax);
} // class Toggler

/// `fix` function signature
typedef TogglerStateFixer = bool Function(Toggler oldState, Toggler newState);

/// `after` function signature
typedef TogglerAfterChange = void Function(Toggler oldState, Toggler current);

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
