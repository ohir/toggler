// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

/// Toggler library can be a part of any state management solution. While it is
/// designed for use in singleton aka "ambient" Models, it also may support
/// _reactive_ architectures via its `state` and `clone` copying constructors.
/// For safe use as a singleton Toggler has built-in data race detection and
/// automatic abandon of an outdated change.
///
/// Toggler supports pre-commit state validation and mutation. After any single
/// change it first fires `fix` state transition handler, then commits new state
/// `fix` prepared, then calls `after` (or signals `notifier`) to inform outer
/// world of changes made. This way Toggler implements a classic MVVM and
/// similar newer architectures unidirectional flow of state changes.
///
/// Toggler is small, fast, and it has no dependecies.
///
/// Test coverage: **100.0%** (162 of 162 lines)
library toggler;

const _noweb = 0; // 0:web 10:noWeb // dart2js int is 53 bit
const _bf = 52 + _noweb; // flag bit
const _im = 51 + _noweb; // item max bit

/// Last usable bit index. While it could be 62, it is now 51 to enable web use.
/// If you need no web and really need 10 more flags you may use source package
/// and update it with `const _noweb = 10;`
const tgIndexMax = _im;

/// Toggler class keeps state of up to 52 boolean values (bits, items) that can
/// be manipulated one by one or in concert.
///
/// _Radio group_ behaviour can be declared on up to 17 separated groups of
/// items. Independent _disabled_ flag is avaliable for every item, to be used
/// in UI builders.  Each value can be retrieved using index[] operator, usually
/// with a constant symbolic name.  By convention Toggler const indice use `tg`
/// (togglee) name prefix, and its respective const bitmask uses `sm` (select
/// mask) prefix. Eg.  `const tgPrize = 33; const smPrize = 1 << tgPrize;`
///
/// _In package's tool/ directory there is a script that generates stub
/// constants together with their masks_.
class Toggler {
  /// togglee item 0..51 value bit:     1:set 0:cleared.
  int tg;

  /// togglee item 0..51 disable bit:   1:disabled 0:enabled.
  ///
  /// Note that class api operates in terms of "active", ie. on
  /// negation of _ds_ bits.
  int ds;

  /// radio-groups 0..51 (mask):        1:member of adjacent 1s group.
  int rg;

  /// recently changed at 0..51 (bits): 1:at this bit index.
  ///
  /// changed bits indicator tells indice of all state changes, both in _tg_ and
  /// in _ds_.  At `fix` call _newState.chb_ will have only one bit set, for use
  /// in `fix` code, then after `fix` _chb_ will be updated to reflect **all**
  /// changed indice, including ones changed by `fix`. Use _changed_ method to
  /// access _chb_ in a readable way.
  int chb;

  /// history hash keeps `serial` and `recent` values.  Live Toggler updates
  /// `hh` on each state change. State copies have `hh` frozen at values origin
  /// had at copy creation time.
  ///
  /// Note: Whether `hh` should be serialized and restored depends on App's
  /// state management architecture used.
  int hh;

  /// handler `void after(Toggler oldState, Toggler current)`
  /// is called after state change has been _commited_. If not null, it is
  /// expected to deal also with after-change notifications. Eg. by passing
  /// current _chb_ to _notifier_ in its very last line:
  /// `if (current.notifier != null) current.notifier!.pump(current.chb);`
  TogglerAfterChange? after;

  /// Concrete implementation of ToggleNotifier class. If given, it will be
  /// _pumped_ with _chb_ after any change if _fix_ will return _true_ and new
  /// state is not _done_. If both _notifier_ object and _after_ handler are
  /// given, _notifier_ is **not** run automatically: if needed, you should
  /// _pump_ it from within your _after_ handler yourself. Ie. your last line
  /// of _after_ handler should say `current.notifier!.pump(current.chb);`
  ToggledNotifier? notifier;

  /// handler `bool fix(Toggler oldState, Toggler newState)`
  /// manages state transitions. Eg. enabling or disabling items if some
  /// condition is met.  If `fix` is null every single state change from a
  /// setter is commited immediately.
  ///
  /// On _true_ return, _newState_ will be commited, ie. copied to the live
  /// Toggler object in a single run.  Then `after` part will run, if present
  /// and unless supressed.
  ///
  /// A `fix` code may suppress subsequent `after` call by setting _done_ flag
  /// on a _newState_. This internal _done_ state is not copied to the live
  /// Toggler on commit.
  ///
  /// In simpler Apps `fix` state handler is the only place where business-logic
  /// is implemented and where Model state transitions occur. In _reactive_
  /// state management, usually `after` is null and `fix` alone sends state
  /// copies up some Stream.
  TogglerStateFixer? fix;

  /// All Toggler members are public for easy tests and custom serialization.
  /// Toggler object with any state transition handler (`fix`, `after`,
  /// `notifier`) non null is said to be a _live_ one. Otherwise, if all
  /// handlers are null, it is a _state copy_ object.
  Toggler({
    this.fix,
    this.after,
    this.notifier,
    this.chb = 0,
    this.tg = 0,
    this.ds = 0,
    this.rg = 0,
    this.hh = 0,
  }) {
    rg = rg.toUnsigned(_im); // never copy with done
  }

  /// _done_ flag can be set on a _live_ Toggler by an outer code. 'Done' always
  /// is cleared at any state change, ie. right after setter runs.
  ///
  /// Both `fix` and `after` handlers may test _oldState_ whether _done_ was
  /// set.  The `fix` handler may also set _done_ on a _newState_ to suppress
  /// subsequent _after_ (_done_ from `fix` does __not__ make to the commited
  /// new state).
  ///
  /// In _reactive_ settings _done_ flag can be set on a state clone to mark it
  /// as "being spent". Note that _done_ flag __always__ comes cleared on all new
  /// copies and clones - whether made of live object or of a state copy.
  bool get done => rg & 1 << _bf != 0;
  set done(bool e) => e ? rg |= 1 << _bf : rg = rg.toUnsigned(_im);

  /// Error flag is set if index was not in 0..51 range, or if data race occured.
  ///
  /// In release code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken: as in debug
  /// builds an assertion should threw right after setting _error_ or _race_.
  bool get error => tg & 1 << _bf != 0;
  set error(bool e) => e ? tg |= 1 << _bf : tg = tg.toUnsigned(_im);

  /// diagnostics flag set internally if Toggler live object was modified while
  /// `fix` has been doing changes based on an older state.
  ///
  /// If such a race occurs, changes based on older state are **not** applied
  /// (are lost).  Races should not happen with _fix_ calling only sync code,
  /// but may happen if fix awaited for something slow.
  bool get race => ds & 1 << _bf != 0;
  set race(bool e) => e ? ds |= 1 << _bf : ds = ds.toUnsigned(_im);

  /// index of the most recent single change coming from a state setter
  int get recent => hh.toUnsigned(6);

  /// monotonic counter increased on each state change. In _state copies_
  /// `serial` is frozen at value origin had at copy creation time.
  int get serial => hh.toUnsigned(_bf) >> 16;

  int _v(int i) {
    assert(i < _bf && i >= 0, 'Toggler index ($i) out of range!');
    if (i < _bf && i > 0) return i;
    error = true;
    return 0;
  }

  // /* methods */ /////////////////////////////////////////////////////////////
  /// _true_ if any item is set, optionally test can be confined to positions
  /// provided with _smMask_ (relevant bit: 1), or within a given _first..last_
  /// indice range. The _smMask_ has higher priority than optional range, so
  /// either query with _smMask_ or with _first..last_, not both.
  bool anyInSet({int tgFirst = 0, int tgLast = _im, int smMask = 0}) {
    if (smMask != 0) return tg & smMask != 0 || ds & smMask != 0;
    tgFirst = _v(tgFirst);
    tgLast = _v(tgLast);
    if (tgFirst > tgLast) return false;
    int n = 1 << tgFirst;
    while (tgFirst < _bf && tgFirst <= tgLast) {
      if (tg & n != 0) return true;
      n <<= 1;
      tgFirst++;
    }
    return false;
  }

  /// _true_ if Toggler item at _tgIndex_ is enabled (has _ds_ bit 0).
  bool active(int i) => ds & (1 << _v(i)) == 0;

  /// _true_ if latest changes happened at _i_ index, or at one of _smMask_
  /// set (1) positions.
  bool changed({int? i, int smMask = 0}) {
    if (i != null && smMask == 0) return chb & (1 << _v(i)) != 0;
    if (i == null) return chb ^ smMask != 0;
    return smMask & chb & (1 << _v(i)) != 0;
  }

  /// clear (to _0_, _off_, _false_ state) item at _tgIndex_.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will be cleared only if it is active.
  ///
  /// Note that _clear_ does not know about radio groups by itself
  /// so _clear_ of an active radio member will make all in group being off.
  void clear(int tgIndex, {bool ifActive = false}) {
    if (ifActive && !active(tgIndex)) return;
    int ntg = tg;
    ntg &= ~(1 << _v(tgIndex));
    if (ntg != tg) verto(tgIndex, ntg, false, false);
  }

  /// returns a deep copy of the Toggler, including `after`, `notifier`, and
  /// `fix` references; _done_ flag is cleared always.
  Toggler clone() => Toggler(
      notifier: notifier,
      after: after,
      fix: fix,
      tg: tg,
      ds: ds,
      rg: rg,
      chb: chb,
      hh: hh);

  /// _true_ if state of `this` and `other` differs. Optionally just at positions
  /// provided with _smMask_ (1), or within a given _first..last__ indice
  /// range. _smMask_ has higher priority than range, so either query with
  /// _smMask_ or with _first..last_, not both.
  ///
  /// Both range and smMask allow eg. for ChangeNotifiers be distinct for
  /// different parts of a common to the App Toggler.
  bool differsFrom(Toggler other,
      {int tgFirst = 0, int tgLast = _im, int smMask = 0}) {
    if (smMask != 0) {
      return tg & smMask != other.tg & smMask ||
          ds & smMask != other.ds & smMask;
    }
    if (tgFirst > _im ||
        tgLast > _im ||
        tgLast < 0 ||
        tgFirst < 0 ||
        tgFirst > tgLast) {
      assert(
          false, 'Bad range. Valid ranges: 0 <= first <= last < 52web|63aot');
      return false; // do nothing on release
    }
    int p = tgFirst;
    int n = 1 << tgFirst;
    int d = tg ^ other.tg;
    while (p < _bf && p <= tgLast) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    p = tgFirst;
    n = 1 << tgFirst;
    d = ds ^ other.ds;
    while (p < _bf && p <= tgLast) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    return false;
  }

  /// enable item at _tgIndex_.
  void enable(int tgIndex) => setDS(tgIndex, false);

  /// disable item at _tgIndex_.
  void disable(int tgIndex) => setDS(tgIndex, true);

  /// _true_ if other copy has been created after us. A live Toggler object
  /// (one with a non-null _after_ function) can never be older than a copy or
  /// other live Toggler.
  ///
  /// Note! A concession is made for _reactive_ uses: live state clones with
  /// only `fix` attached compare with each other just as copies do.
  bool isOlderThan(Toggler other) => after != null
      ? false
      : other.after != null
          ? true
          : hh.toUnsigned(_bf) >> 16 < other.hh.toUnsigned(_bf) >> 16;

  /// radioGroup declares a range of items that have "one of" behaviour.
  /// Ranges may not overlap nor even be adjacent. Ie. there must be at least
  /// one non-grouped item placed between two radio groups. Eg. ranges 0..3 and
  /// 5..7 (gap at 4) are OK but 0..3 and 4..6 are not (no 3 to 4 gap).
  /// Gap index is fully usable for an independent item.
  ///
  /// Allowed group boundaries are: `0 <= first < last < 53`, if this condition
  /// is not met, or ranges touch or overlap, radioGroup will throw on debug
  /// build, or it will set error flag on _release_ build.
  ///
  /// A radioGroup creation does not `after`. Any number of calls to radioGroup
  /// can be replaced by assigning a predefined constant to the `rm` member.
  void radioGroup(int tgFirst, int tgLast) {
    if (tgFirst > _im ||
        tgLast > _im ||
        tgLast < 0 ||
        tgFirst < 0 ||
        tgFirst >= tgLast) {
      error = true;
      assert(false,
          'Bad radio range. Valid ranges: 0 <= first < last < _b63 | first:$tgFirst last:$tgLast');
      return; // do nothing at release
    }
    var nrm = rg;
    var i = tgFirst;
    var c = 1 << (tgFirst - (i == 0 ? 0 : 1));
    bool overlap() {
      if (rg & c != 0) {
        error = true;
        assert(false,
            'Radio ranges may NOT overlap nor be adjacent to each other [$tgFirst..$tgLast])');
        return true;
      }
      return false;
    }

    if (overlap()) return; // i-1
    if (i > 0) c <<= 1;
    while (true) {
      if (overlap()) return; // i
      if (i > tgLast) break;
      nrm |= c;
      c <<= 1;
      i++;
    }
    rg = nrm;
  }

  /// set (_1_, _on_, _true_) item at index _tgIndex_.  By default state changes are
  /// not suppresed, but an optional argument `ifActive: true` mandates prior
  /// _active_ check. Ie. item will be set only if it is active.
  void set1(int tgIndex, {bool ifActive = false}) {
    if (ifActive && !active(tgIndex)) return;
    tgIndex = _v(tgIndex);
    int ntg = tg;
    if (rg & (1 << tgIndex) != 0) {
      // clear all in this radio group
      int k = tgIndex;
      int n = 1 << tgIndex;
      while (k < _bf && rg & n != 0) {
        ntg &= ~n;
        n <<= 1;
        k++;
      }
      k = tgIndex;
      n = 1 << tgIndex;
      while (k >= 0 && rg & n != 0) {
        ntg &= ~n;
        n >>= 1;
        k--;
      }
    }
    ntg |= 1 << tgIndex;
    if (ntg != tg) verto(tgIndex, ntg, false, true);
  }

  /// sets done flag and returns _true_.  It is a debug helper method used in
  /// Flutter code for `markDone() ? : null,` constructs placed at possible end
  /// of a `build` method, eg. to notify yourself that some conditional build
  /// completed at an expected path.
  bool markDone() => (rg |= 1 << _bf) != 0;

  /// disable (true) or enable (false) an item at index _tgIndex_.
  ///
  /// Note that _ds_ property has bit set to 1 for _disabled_ items.
  void setDS(int i, bool disable) {
    int nds = ds;
    disable ? nds |= 1 << _v(i) : nds &= ~(1 << _v(i));
    if (nds != ds) verto(i, nds, true, disable);
  }

  /// sets item state at _tgIndex_ to the given _state_ value.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie.  item will change state only if it is active.
  void setTo(int i, bool state, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    state ? set1(i) : clear(i);
  }

  /// get copy of state; _done_ flag and handlers are cleared on the copy.
  Toggler state() => Toggler(tg: tg, ds: ds, rg: rg, chb: chb, hh: hh);

  /// toggle changes item at index _tgIndex_ to the opposite state.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will change state only if it is active.
  ///
  /// Note that toggle does not know about radio groups by itself
  /// so toggle on an active radio will make all in group being off.
  void toggle(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    if (tg & (1 << _v(i)) != 0) {
      int ntg = tg;
      ntg &= ~(1 << i);
      if (ntg != tg) verto(i, ntg, false, false);
    } else {
      set1(i);
    }
  }

  /// _true_ if Toggler item at _index_ is set (`tg` item bit is 1).
  bool operator [](int tgIndex) => tg & (1 << _v(tgIndex)) != 0;

  /// unconditionally set value of item at index _tgIndex_.
  void operator []=(int tgIndex, bool v) => setTo(tgIndex, v);

  /// Toggler state change engine. Exposed only to allow straighforward testing
  /// and debugging Apps.  Do not call yourself `verto` unless you really really
  /// KWYAD.  For legitimate use of `verto` see `replay(cas)` method in examples
  /// TogglerReplay extension. (_Verto means 'to turn' in Latin_).
  void verto(int i, int nEW, bool isDs, bool actSet) {
    if (after == null && notifier == null && fix == null) {
      chb = isDs ? ds ^ nEW : tg ^ nEW;
      isDs ? ds = nEW : tg = nEW;
      return;
    }
    final oldS = Toggler(tg: tg, ds: ds, rg: rg, hh: hh);
    if (done) oldS.markDone(); // fix and after should know
    final nhh = (((hh.toUnsigned(_bf) >> 16) + 1) << 16) | // serial++
        ((hh.toUnsigned(16) & 0xff00) | // b15..b8 extensions reserved
            (isDs ? (1 << 7) : 0) | // cabyte b7: tg/ds
            (actSet ? (1 << 6) : 0) | //      b6: clear/set
            i.toUnsigned(6)); //          b5..b0: item index
    if (fix != null) {
      final newS =
          Toggler(tg: isDs ? tg : nEW, ds: isDs ? nEW : ds, rg: rg, hh: nhh);
      newS.chb = isDs ? ds ^ nEW : tg ^ nEW; // pass coming single change bit
      if (fix!(oldS, newS)) {
        if (hh != oldS.hh) {
          ds |= 1 << _bf;
          error = true;
          assert(hh == oldS.hh,
              'Data race detected on state update! [cabyte: ${hh.toUnsigned(8)}]');
          return;
        }
        tg = newS.tg;
        ds = newS.ds;
        hh = newS.hh;
        rg = newS.rg; // may come 'done'
        chb = (tg ^ oldS.tg) | (ds ^ oldS.ds); // set "changed" bits
      }
    } else {
      hh = nhh;
      rg = rg.toUnsigned(_im);
      chb = isDs ? ds ^ nEW : tg ^ nEW;
      isDs ? ds = nEW : tg = nEW;
    }
    if (after != null) {
      done ? rg = rg.toUnsigned(_im) : after!(oldS, this);
    } else if (notifier != null) {
      done ? rg = rg.toUnsigned(_im) : notifier!.pump(chb);
    }
  }
} // class Toggler

/// `fix` function signature
typedef TogglerStateFixer = bool Function(Toggler oldState, Toggler newState);

/// `after` function signature
typedef TogglerAfterChange = void Function(Toggler oldState, Toggler current);

// coverage:ignore-start
/// Toggler's change notification dispatcher, an abstract interface.
/// Concrete implementation can be found eg. in `package:uimodel/uimodel.dart`
///
/// _Note: docs example code below uses `WatchX` of `get_it_mixin` package:
/// neither `WatchX` is a part of Toggler, nor Toggler depends on get_it_mixin.
/// See Flutter example for concrete implementation of ToggledNotifier (the
/// _UiNotifier_ class)._
abstract class ToggledNotifier {
  // @mustBeOverridden
  /// the _chb_ recent changes bitmask is to be pumped here.
  /// Automatically, if an implementation is provided to Toggler _notifier_.
  void pump(int chb) => throw UnimplementedError('pump not implemented');

  // @mustBeOverridden
  /// used to get _masked_ notifiers,
  /// eg. `watch(m(tmDn | tmUp));`
  dynamic call(int smMask) => throw UnimplementedError('call not implemented');

  // @mustBeOverridden
  /// used to get _indexed_ notifiers
  /// eg. `watch(m.single(tgSendAction);`
  dynamic single(int index) =>
      throw UnimplementedError('single(index) not implemented');

  /// set _indexed_ notifiers, use "add" only in mocks for test pipelines
  bool addIndexed(int index, dynamic value) => false;

  /// add _masked_ notifier, use "add" only in mocks for test pipelines
  bool addMasked(int smMask, dynamic value) => false;
}
// coverage:ignore-end
