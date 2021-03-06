library mm;

import 'dart:collection';

import 'property.dart';

abstract class Model {

  static final Map<String, _ModelData> _modelname_modeldata_map = {};

  static Model? getModel (ModelHandler handler, dynamic id) {
    if (_modelname_modeldata_map.containsKey(handler.model_name) == false)
      return null;
    
    final model_data = _modelname_modeldata_map[handler.model_name];
    return model_data!.getModel(id);
  }

  static void putModel (ModelHandler handler, Model model) {
    if (_modelname_modeldata_map.containsKey(model.model_name) == false)
      _modelname_modeldata_map[model.model_name] = _ModelData(queue_size: handler.queue_size);
    
    final model_data = _modelname_modeldata_map[model.model_name];
    model_data!.putModel(model);
  }

  static Model getOrNewModel (
      ModelHandler handler,
      dynamic id,
  ) {

    if (_modelname_modeldata_map.containsKey(handler.model_name) == false)
      _modelname_modeldata_map[handler.model_name] = _ModelData(queue_size: handler.queue_size);
    
    final model_data = _modelname_modeldata_map[handler.model_name];

    var m = model_data!.getModel(id);
    if (m == null) {
      m = handler.newInstance(id);
      model_data.putModel(m);
    }

    return m;
  }

  static Future<Model?> fetchModelWithPropertyNames (
      ModelHandler handler,
      dynamic id,
      List<String> property_names,
      {
        Map<String, dynamic>? user_data,
      }
  ) async {
    final m = getOrNewModel(handler, id);
    await m.fetch(property_names.where((e)=>m.getProperty(e)!=null).map<Property>((e)=>m.getProperty(e)!).toList(), user_data);
    return m;
  }

  static Future<Model?> fetchModel (
      ModelHandler handler,
      dynamic id,
      List<Property> properties,
      {
        Map<String, dynamic>? user_data,
      }
  ) async {
    final m = getOrNewModel(handler, id);
    await m.fetch(properties, user_data);
    return m;
  }

  static Future<T?> createModel<T extends Model> (
      ModelHandler handler,
      Map<Property, dynamic> property_value_map,
      {
        Map<String, dynamic>? user_data,
      }
  ) async {
    final m = await handler.onCreate<T>(property_value_map, user_data);
    if (m == null)
      return null;
    
    putModel(handler, m);
    return m;
  }

  static Future<void> deleteModel (
      ModelHandler handler,
      dynamic id,
      {
        Map<String, dynamic>? user_data,
      }
  ) async {
    if (_modelname_modeldata_map.containsKey(handler.model_name) == true) {
      final model_data = _modelname_modeldata_map[handler.model_name]!;
      final m = model_data.getModel(id);
      if (m == null)
        return;
      
      model_data.removeModel(m);
    }
    return handler.onDelete(id, user_data);
  }


  final Map<String, Property> _name_property_map = {};
  int _fetch_start_ts = 0;
  final int _fetch_timeout_ms;

  dynamic get id;
  String get model_name;
  ModelHandler get handler;

  Model ({int fetch_timeout_ms = 10000}):
      _fetch_timeout_ms = fetch_timeout_ms;

  void setProperties (List<Property> properties) {
    for (final p in properties) {
      p.sys_setModel(this);
      _name_property_map[p.name] = p;
    }
  }

  Property? getProperty (String name) {
    if (_name_property_map.containsKey(name) == false)
      return null;
    return _name_property_map[name];
  }

  bool isDirty () {
    for (final p in _name_property_map.values) {
      if (p.is_dirty == true)
        return true;
    }

    return false;
  }

  void setByJson (
      Map<String, dynamic> json,
      {
        Map<String, dynamic>? user_data,
      }
  ) {
    for (final k in json.keys) {
      if (_name_property_map.containsKey(k) == false) {
        if (k != 'id' && k != '(non_model_data)' && handler.isValidKey(k) == false)
          print('no property "$k" in $model_name');
        continue;
      }
      _name_property_map[k]!.setValue(json[k]);
    }
  }

  void startFetch () {
    _fetch_start_ts = DateTime.now().millisecondsSinceEpoch;
  }

  void endFetch () {
    _fetch_start_ts = 0;
  }

  bool isFetching () {
    return (DateTime.now().millisecondsSinceEpoch - _fetch_start_ts) < _fetch_timeout_ms;
  }

  Future<void> onFetch (
      List<Property> properties,
      Map<String, dynamic>? user_data,
  );

  Future<void> fetch (
      List<Property> properties,
      Map<String, dynamic>? user_data,
  ) async {
    if (isDirty() == false)
      return;
    
    if (isFetching() == true) {
      while (isFetching() == true)
        await Future.delayed(Duration(milliseconds: 100));
      return;
    }
    
    startFetch();
    await onFetch(properties.where((e)=>e.is_dirty == true).toList(), user_data);
    endFetch();
  }

  Future<void> onUpdate (
      Map<Property, dynamic> property_value_map,
      Map<String, dynamic>? user_data,
  );

  Future<void> update (
      Map<Property, dynamic> property_value_map,
      Map<String, dynamic>? user_data,
  ) async {
    await onUpdate(property_value_map, user_data);
    property_value_map.keys.forEach((e) => e.dirty());
    return fetch(property_value_map.keys.toList(), user_data);
  }
}

class _ModelLLE extends LinkedListEntry<_ModelLLE> {
  Model value;
  _ModelLLE(this.value);

  @override
  String toString() => '${super.toString()}: $value';
}

class _ModelData {
  final int _queue_size;
  final Map<dynamic, Model> _id_model_map = {};
  final LinkedList<_ModelLLE> _models = LinkedList<_ModelLLE>();

  _ModelData({int queue_size = 1000000}): _queue_size = queue_size;

  Model? getModel (dynamic id) {
    if (_id_model_map.containsKey(id) == false)
      return null;
    return _id_model_map[id];
  }

  void putModel (Model model) {
    if (_id_model_map.containsKey(model.id) == true)
      return;
    
    _id_model_map[model.id] = model;
    _models.add(_ModelLLE(model));

    while (_models.length > _queue_size) {
      final first = _models.first;
      _id_model_map.remove(first.value.id);
      _models.remove(first);
    }
  }

  void removeModel (Model model) {
    try {
      final ent = _models.firstWhere((e) => e.value == model);
      _id_model_map.remove(ent.value.id);
      _models.remove(ent);
    }catch (e) {
      ;
    }
  }
}

abstract class ModelHandler {
  int get queue_size => 1000000;

  String get model_name;

  Model newInstance (dynamic id);

  bool isValidKey (String key) {
    return false;
  }

  Future<T?> onCreate<T extends Model> (
      Map<Property, dynamic> property_value_map,
      Map<String, dynamic>? user_data,
  );

  Future<void> onDelete (
      dynamic id,
      Map<String, dynamic>? user_data,
  );
}