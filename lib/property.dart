library mm;

import 'dart:math';

import 'model.dart';


typedef PropertyChangeListenerFunc = void Function ();

class Property<T> {
  static PropertyValueConverter value_converter = PropertyValueConverter();


  Model? _model;
  final String _name;
  T? _value;
  int _last_updated_ts = 0;
  final int _lifetime_ms;

  final List<PropertyChangeListenerFunc> _listeners = [];

  Model? get model => _model;  
  String get name => _name;
  T? get value => _value;
  dynamic get json_value => value_converter.fromValue<T>(_value);
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
    _value = value_converter.toValue<T>(v);
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



class PropertyValueConverter {
  T? toValue<T> (dynamic json_value) {
    if (T == DateTime)
      return DateTime.parse(json_value as String) as T;
    if (json_value is Map) {
      if (json_value.containsKey('type') && json_value['type'] == 'Point' && json_value.containsKey('coordinates'))
        return Point<num>(json_value['coordinates'][0] as num, json_value['coordinates'][1] as num) as T;
    }

    return json_value as T;
  }

  dynamic fromValue<T> (T? value) {
    return value;
  }
}