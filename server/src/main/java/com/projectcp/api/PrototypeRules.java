package com.projectcp.api;

import java.util.*;

/** 기존 프로토타입의 임시 규칙을 옮긴다. 최종 클라이언트·서버 책임 분담은 미정이다. */
final class PrototypeRules {
    private PrototypeRules() {}

    static Map<String, Object> initialState() { return MvpRules.initialState(); }

    static Map<String, Object> legacyInitialState() {
        var s = new LinkedHashMap<String, Object>();
        s.putAll(Map.of("week", 1, "day", 0, "phase", "character", "money", 80,
                "strength", 50, "luck", 50, "stamina", 80, "meal", "", "gear", "basic"));
        s.putAll(Map.of("packed", new ArrayList<>(), "cooking", 0,
                "ingredients", new ArrayList<>(), "rested", false, "job_done", false,
                "stars", 0, "recipes", new LinkedHashMap<>()));
        s.put("character_id", "");
        return s;
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> copy(Map<String, Object> source) {
        var result = new LinkedHashMap<String, Object>();
        source.forEach((key, value) -> result.put(key, copyValue(value)));
        return result;
    }

    private static Object copyValue(Object value) {
        if (value instanceof Map<?, ?> map) {
            var result = new LinkedHashMap<String, Object>();
            map.forEach((k, v) -> result.put((String) k, copyValue(v)));
            return result;
        }
        if (value instanceof List<?> list) {
            var result = new ArrayList<>();
            list.forEach(v -> result.add(copyValue(v)));
            return result;
        }
        return value;
    }

    static int number(Map<String, Object> s, String key) { return ((Number) s.get(key)).intValue(); }
    static void add(Map<String, Object> s, String key, int delta) { s.put(key, number(s, key) + delta); }
    static void recover(Map<String, Object> s, String key, int delta) { s.put(key, Math.min(100, number(s, key) + delta)); }
    static void spend(Map<String, Object> s, String key, int amount) { s.put(key, Math.max(0, number(s, key) - amount)); }

    static Map<String,Object> transition(Map<String,Object> current,String command,String choice,Map<String,Object> body) {
        return current.containsKey("mvp_version")?MvpRules.transition(current,command,choice,body):transition(current,command,choice);
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> transition(Map<String, Object> current, String command, String choice) {
        if(current.containsKey("mvp_version"))return MvpRules.transition(current,command,choice,Map.of());
        if(command.equals("upgrade_mvp")) {
            if(!Set.of("character","work","shopping","settlement").contains(current.get("phase")))
                throw new IllegalArgumentException("이번 주를 마친 뒤 새 MVP로 이어갈 수 있어요.");
            return MvpRules.upgrade(current);
        }
        var s = copy(current);
        var phase = (String) s.get("phase");
        var packed = (List<String>) s.get("packed");
        var ingredients = (List<String>) s.get("ingredients");
        boolean improved = "improved".equals(s.get("gear"));
        if (phase.equals("character") && command.equals("select_character")) {
            if (!Set.of("female", "male").contains(choice))
                throw new IllegalArgumentException("캐릭터를 선택해 주세요.");
            s.put("character_id", choice);
            s.put("phase", "work");
        } else if (phase.equals("work") && command.equals("job") && !Boolean.TRUE.equals(s.get("job_done"))) {
            add(s, "money", 15); spend(s, "stamina", 8); s.put("job_done", true);
        } else if (phase.equals("work") && command.equals("work")) {
            add(s, "money", 10); spend(s, "stamina", 6); spend(s, "strength", 2); spend(s, "luck", 1);
            add(s, "day", 1); s.put("job_done", false);
            if (number(s, "day") == 5) s.put("phase", "shopping");
        } else if (phase.equals("shopping") && command.equals("buy") && Set.of("ramen", "skewer").contains(choice)) {
            int cost = choice.equals("ramen") ? 20 : 25;
            if (number(s, "money") < cost) throw new IllegalArgumentException("재료를 살 돈이 부족해요.");
            add(s, "money", -cost); s.put("meal", choice); s.put("phase", "packing");
        } else if (phase.equals("packing") && command.equals("pack") && Set.of("tent", "table", "chair").contains(choice)) {
            if (!packed.remove(choice)) packed.add(choice);
        } else if (phase.equals("packing") && command.equals("gear") && Set.of("basic", "improved").contains(choice)) {
            s.put("gear", choice);
        } else if (phase.equals("packing") && command.equals("next") && packed.size() == 3) {
            s.put("phase", "setup"); s.put("setup", 0);
        } else if (phase.equals("setup") && command.equals("install")) {
            add(s, "setup", 1); spend(s, "stamina", 2);
            if (number(s, "setup") == 3) s.put("phase", "free");
        } else if (Set.of("free", "night").contains(phase) && command.equals("rest") && !Boolean.TRUE.equals(s.get("rested"))) {
            recover(s, "stamina", improved ? 12 : 6); s.put("rested", true);
        } else if (Set.of("free", "night").contains(phase) && command.equals("next")) {
            s.put("phase", phase.equals("free") ? "dinner" : "breakfast"); s.put("rested", false);
        } else if (phase.equals("dinner") && command.equals("ingredient") && "skewer".equals(s.get("meal"))
                && Set.of("meat", "mushroom").contains(choice) && ingredients.size() < 3) {
            ingredients.add(choice);
        } else if (phase.equals("dinner") && command.equals("cook")) {
            if (s.get("meal").equals("skewer") && ingredients.size() != 3)
                throw new IllegalArgumentException("꼬치 재료 세 개를 먼저 골라 주세요.");
            add(s, "cooking", 1);
            if (number(s, "cooking") >= (improved ? 2 : 3)) {
                var sorted = new ArrayList<>(ingredients); Collections.sort(sorted);
                String key = s.get("meal") + ":" + String.join(",", sorted);
                var recipes = (Map<String, Map<String, Object>>) s.get("recipes");
                var recipe = recipes.computeIfAbsent(key, ignored -> new LinkedHashMap<>(Map.of("stars", 0, "mastery", 0)));
                if (number(recipe, "stars") >= 3) recipe.put("mastery", Math.min(3, number(recipe, "mastery") + 1));
                recover(s, "stamina", 20 + (improved ? 8 : 0) + number(recipe, "mastery"));
                recover(s, "strength", 5 + Collections.frequency(ingredients, "meat") * 3);
                recover(s, "luck", 5 + Collections.frequency(ingredients, "mushroom") * 3);
                recipe.put("stars", Math.max(number(recipe, "stars"), improved ? 3 : 2));
                s.put("stars", number(recipe, "stars") + (number(recipe, "mastery") == 3 ? 1 : 0));
                s.put("phase", "night");
            }
        } else if (phase.equals("breakfast") && command.equals("breakfast")) {
            recover(s, "stamina", 10); s.put("phase", "teardown"); s.put("teardown", 0);
        } else if (phase.equals("teardown") && command.equals("pack_up")) {
            add(s, "teardown", 1);
            if (number(s, "teardown") == 3) s.put("phase", "settlement");
        } else if (phase.equals("settlement") && command.equals("next")) {
            add(s, "week", 1); s.put("day", 0); s.put("phase", "work"); s.put("meal", "");
            s.put("packed", new ArrayList<>()); s.put("cooking", 0); s.put("ingredients", new ArrayList<>());
            s.put("rested", false); s.put("job_done", false);
        } else {
            throw new IllegalArgumentException("현재 단계에서 할 수 없는 행동이에요.");
        }
        return s;
    }
}
