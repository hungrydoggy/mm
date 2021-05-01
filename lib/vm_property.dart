library mm;

import 'model.dart';
import 'property.dart';
import 'view_model.dart';


class VMProperty<T> {
  final ModelSelector _model_selector;
  final dynamic _model_id;
  final String _property_name;

  ViewModel? _view_model;
  Property<T>? _property;

  ModelSelector get model_selector => _model_selector;
  dynamic get model_id => _model_id;
  String get property_name => _property_name;
  ViewModel? get view_model => _view_model;
  Property<T>? get property => _property;
  bool get is_inited => _property != null;
  bool get is_dirty => (_property == null)? true: _property!.is_dirty;

  T? get value {
    if (_property == null)
      return null;
    
    return _property!.value;
  }

  VMProperty (this._model_selector, this._model_id, this._property_name);

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
      _view_model!.onPropertyChanged(this);
  }
}