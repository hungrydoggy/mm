library mm;

import 'model.dart';


typedef PropertyChangeListenerFunc = void Function ();
typedef PropertyToValueFunc<T>   = T? Function (dynamic json_value);
typedef PropertyFromValueFunc<T> = dynamic Function (T? value);

T? _defaultToValueFunc<T> (dynamic json_value) {
  return json_value as T;
}
dynamic _defaultFromValueFunc<T> (T? value) {
  return value;
}

class Property<T> {
  static PropertyToValueFunc   _to_value_func   = _defaultToValueFunc;
  static PropertyFromValueFunc _from_value_func = _defaultFromValueFunc;

  static void setToValueFunc (PropertyToValueFunc f) {
    _to_value_func = f;
  }

  static void setFromValueFunc (PropertyFromValueFunc f) {
    _from_value_func = f;
  }


  Model? _model;
  final String _name;
  T? _value;
  int _last_updated_ts = 0;
  final int _lifetime_ms;

  final List<PropertyChangeListenerFunc> _listeners = [];

  Model? get model => _model;  
  String get name => _name;
  T? get value => _value;
  dynamic get json_value => _from_value_func(_value);
  int get last_updated_ts => _last_updated_ts;
  int get lifetime_ms => _lifetime_ms;
  bool get is_dirty => (DateTime.now().millisecondsSinceEpoch - _last_updated_ts) > _lifetime_ms;
  
  Property ({required String name, T? default_value, int lifetime_ms = 1000}):
      _name        = name,
      _value       = default_value,
      _lifetime_ms = lifetime_ms;
  
  void dirty () {
    _last_updated_ts = 0;
  }

  void setValue (dynamic v) {
    _value = _to_value_func(v);
    _last_updated_ts = DateTime.now().millisecondsSinceEpoch;
    for (final f in _listeners)
      f();
  }

  // called by system
  void sys_setModel (Model model) {
    _model = model;
  }

  void addOnPropertyChangedListener (PropertyChangeListenerFunc f) {
    removeOnPropertyChangedListener(f);
    _listeners.add(f);
  }

  void removeOnPropertyChangedListener (PropertyChangeListenerFunc f) {
    final idx = _listeners.indexOf(f);
    if (idx < 0)
      return;
    
    _listeners[idx] = _listeners.last;
    _listeners.removeLast();
  }
}
