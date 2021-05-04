library mm;

import 'model.dart';
import 'property.dart';
import 'vm_property.dart';


typedef VMPropertyChangeListenerFunc = void Function (VMProperty vmp);

class ViewModel {

  List<VMProperty> _vm_properties = [];
  final Map<VMProperty, bool> _vmproperty_check_map = {};
  List<ViewModel> _nesteds = [];
  final Map<ViewModel, bool> _nested_check_map = {};
  ViewModel? _parent_vm;
  bool _is_initing = false;
  final List<VMPropertyChangeListenerFunc> _listeners = [];

  void setProperties (List<VMProperty> properties) {
    _vm_properties = properties;
    _vmproperty_check_map.clear();
    for (final vmp in _vm_properties) {
      _vmproperty_check_map[vmp] = true;
      vmp.sys_setViewModel(this);
    }
  }

  void setNestedVMs (List<ViewModel> nesteds) {
    _nesteds = nesteds;
    _nested_check_map.clear();
    for (final n in _nesteds) {
      _nested_check_map[n] = true;
      n._parent_vm = this;
    }
  }

  bool isInited () {
    for (final vmp in _vm_properties) {
      if (vmp.is_inited == false)
        return false;
    }
    return true;
  }

  bool isIniting () => _is_initing;

  bool isDirty () {
    for (final vmp in _vm_properties) {
      if (vmp.is_dirty == true)
        return true;
    }
    return false;
  }

  bool isFetching () {
    for (final vmp in _vm_properties) {
      if (vmp.property != null && vmp.property!.model != null && vmp.property!.model!.isFetching() == true)
        return true;
    }
    return false;
  }

  Future<void> init ({VMPropertyChangeListenerFunc? on_vm_property_change}) async {
    if (_is_initing == true) {
      while (_is_initing == true)
        await Future.delayed(Duration(milliseconds: 100));
      return;
    }
    
    _is_initing = true;

    if (on_vm_property_change != null)
      addOnVMPropertyChangedListener(on_vm_property_change);
    
    // classify vm_properties by model_handler and model_id
    final handler_modelid_vmproperties_map = <ModelHandler, Map<int, List<VMProperty>>>{};
    for (final vmp in _vm_properties) {
      if (handler_modelid_vmproperties_map.containsKey(vmp.model_handler) == false)
        handler_modelid_vmproperties_map[vmp.model_handler] = {};
      
      if (handler_modelid_vmproperties_map[vmp.model_handler]!.containsKey(vmp.model_id) == false)
        handler_modelid_vmproperties_map[vmp.model_handler]![vmp.model_id] = [];
      
      handler_modelid_vmproperties_map[vmp.model_handler]![vmp.model_id]!.add(vmp);
    }

    // set property
    for (final ms in handler_modelid_vmproperties_map.keys) {
      final modelid_vmproperties_map = handler_modelid_vmproperties_map[ms]!;
      for (final mid in modelid_vmproperties_map.keys) {
        final vm_properties = modelid_vmproperties_map[mid]!;
        final m = await Model.fetchModelWithPropertyNames(ms, mid, vm_properties.map<String>((e)=>e.property_name).toList());
        for (final vmp in vm_properties)
          vmp.sys_setProperty(m!.getProperty(vmp.property_name)!);
      }
    }

    _is_initing = false;

    return fetch();
  }

  Future<void> fetch () async {
    // ready
    if (isInited() == false) {
      return;
    }
    final futures = <Future<void>>[];


    // fetch nested vms
    for (final vm in _nesteds)
      futures.add(vm.fetch());


    // classify properties by model
    final model_properties_map = <Model, List<Property>>{};
    for (final vmp in _vm_properties) {
      final p = vmp.property!;
      if (p.model == null)
        continue;
      
      if (model_properties_map.containsKey(p.model!) == false)
        model_properties_map[p.model!] = [];
      
      model_properties_map[p.model!]!.add(p);
    }


    // fetch
    for (final m in model_properties_map.keys) {
      final ps = model_properties_map[m];
      if (ps!.isEmpty)
        continue;
      futures.add(m.fetch(ps));
    }


    // awaits
    for (final f in futures)
      await f;
  }

  Future<void> update (Map<VMProperty, dynamic> vmproperty_value_map) async {
    // ready
    if (isInited() == false) {
      return;
    }


    // make property_value_map by model
    final model_property_value_map = <Model, Map<Property, dynamic>>{};
    for (final vmp in vmproperty_value_map.keys) {
      if (_vmproperty_check_map.containsKey(vmp) == false)
        continue;
      
      final p = vmp.property;
      if (p == null || p.model == null)
        continue;
      
      if (model_property_value_map.containsKey(p.model!) == false)
        model_property_value_map[p.model!] = {};
      
      model_property_value_map[p.model!]![vmp.property!] = vmproperty_value_map[vmp];
    }


    // update
    final futures = <Future<void>>[];
    for (final m in model_property_value_map.keys) {
      final pvm = model_property_value_map[m];
      if (pvm!.isEmpty)
        continue;
      futures.add(m.update(pvm));
    }


    // fetch all
    futures.add(_findRoot().fetch());


    // awaits
    for (final f in futures)
      await f;
  }

  // called by system
  void sys_onPropertyChanged (VMProperty vmp) {
    for (final f in _listeners)
      f(vmp);
  }

  void addOnVMPropertyChangedListener (VMPropertyChangeListenerFunc f) {
    removeOnVMPropertyChangedListener(f);
    _listeners.add(f);
  }

  void removeOnVMPropertyChangedListener (VMPropertyChangeListenerFunc f) {
    final idx = _listeners.indexOf(f);
    if (idx < 0)
      return;
    
    _listeners[idx] = _listeners.last;
    _listeners.removeLast();
  }

  void dispose () {
    for (final vmp in _vm_properties)
      vmp.dispose();
  }

  ViewModel _findRoot () {
    var vm = this;
    while (vm._parent_vm != null)
      vm = _parent_vm!;
    return vm;
  }
}