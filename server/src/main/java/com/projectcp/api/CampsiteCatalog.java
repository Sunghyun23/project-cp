package com.projectcp.api;

import java.util.*;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/** 장소별 배치 범위의 기준. 클라이언트가 보낸 범위는 판정에 사용하지 않는다. */
final class CampsiteCatalog {
    private CampsiteCatalog() {}
    private static final Map<String,Object> DATA = load("campsites.json");
    private static final Map<String,Object> SURFACES = load("item-surfaces.json");
    private static Map<String,Object> load(String filename) {
        try (var input = CampsiteCatalog.class.getResourceAsStream("/gameplay/"+filename)) {
            if (input == null) throw new IllegalStateException("Missing campsite catalog");
            return JsonMapper.builder().build().readValue(input,new TypeReference<Map<String,Object>>(){});
        } catch (java.io.IOException e) { throw new IllegalStateException("Invalid campsite catalog",e); }
    }
    @SuppressWarnings("unchecked") static Map<String,Object> site(String id) {
        var sites=(Map<String,Map<String,Object>>)DATA.get("sites");
        if (!sites.containsKey(id)) throw new IllegalArgumentException("장소의 배치 정보를 찾을 수 없어요.");
        var source=sites.get(id);
        if(!"z_up".equals(source.get("coordinate_system")))return source;
        var result=new LinkedHashMap<>(source);
        var raw=(Map<String,Object>)source.get("placement");var area=new LinkedHashMap<>(raw);
        for(String key:List.of("min","max"))area.put(key,toEngine((List<?>)raw.get(key)));
        area.put("ground_y",raw.get("ground_z"));area.put("table_y",raw.get("table_z"));
        var blocked=new ArrayList<Map<String,Object>>();
        for(var value:(List<Map<String,Object>>)raw.get("blocked")) {
            var region=new LinkedHashMap<>(value);
            for(String key:List.of("min","max"))region.put(key,toEngine((List<?>)value.get(key)));
            blocked.add(region);
        }
        area.put("blocked",blocked);result.put("placement",area);result.put("coordinate_system","godot_y_up");
        return result;
    }
    private static List<?> toEngine(List<?> value) {return List.of(value.get(0),value.get(2),value.get(1));}
    @SuppressWarnings("unchecked") static Map<String,Object> area(String id) { return (Map<String,Object>)site(id).get("placement"); }
    static double axis(Map<String,Object> area,String boundary,int axis) { return ((Number)((List<?>)area.get(boundary)).get(axis)).doubleValue(); }
    @SuppressWarnings("unchecked") static List<Map<String,Object>> blocked(String id) { return (List<Map<String,Object>>)area(id).get("blocked"); }
    @SuppressWarnings("unchecked") static Map<String,Object> surface(String id) { return (Map<String,Object>)SURFACES.getOrDefault(id,Map.of("stackable",false)); }
    static Map<String,Object> enrich(Map<String,Object> state) {
        if (!state.containsKey("mvp_version")) return state;
        var result=new LinkedHashMap<>(state);
        result.put("campsite_catalog",DATA);
        result.put("item_catalog",MvpRules.catalog());
        result.put("field_coordinate_system","godot_y_up");
        String id=(String)state.getOrDefault("place","");
        if (!id.isEmpty()) result.put("placement_site",site(id));
        return DocumentWork.enrich(result);
    }
}
