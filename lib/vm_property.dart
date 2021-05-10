library mm;

import 'model.dart';
import 'property.dart';
import 'view_model.dart';


class VMProperty<T> {
  final ModelHandler _model_handler;
  final dynamic _model_id;
  final String _property_name;
  final String? _name_in_vm;

  ViewModel? _view_model;
  Property<T>? _property;

  ModelHandler get model_handler => _model_handler;
  dynamic get model_id => _model_id;
  String get property_name => _property_name;
  String get name => (_name_in_vm != null)? _name_in_vm!: _property_name;
  ViewModel? get view_model => _view_model;
  Property<T>? get property => _property;
  bool get is_inited => _property != null;
  bool get is_dirty => (_property == null)? true: _property!.is_dirty;

  T? get value {
    if (_property == null)
      return null;
    
    return _property!.value;
  }

  VMProperty (this._model_handler, this._model_id, this._property_name, {String? name}): _name_in_vm = name;

  // called by system
  void sys_setProperty (Property<T> p) {
    p.removeOnPropertyChangedListener(_onPropertyChanged);
    _property = p;
    p.addOnPropertyChangedListener(_onPropertyChanged);
    _onPropertyChanged();
  }

  // called by system
  void sys_setViewModel (ViewModel vm) {
    _view_model = vm;
  }

  void dispose () {
    if (_property != null)
      _property!.removeOnPropertyChangedListener(_onPropertyChanged);
  }

  void _onPropertyChanged () {
    if (_view_model != null)
      _view_model!.sys_onPropertyChanged(this);
  }
}