package com.projectcp.api;

import java.util.*;

/** 첫 완주 MVP. 수치·콘텐츠·시간 배율은 테스트 데이터다. */
final class MvpRules {
    private MvpRules() {}
    record Item(String name, int price, int[][] cells) {}
    static final Map<String,Item> ITEMS = new LinkedHashMap<>();
    static {
        ITEMS.put("tent", new Item("텐트", 35, new int[][]{{0,0},{1,0},{2,0},{0,1},{1,1}}));
        ITEMS.put("stove", new Item("버너", 20, rect(2,1)));
        ITEMS.put("chair", new Item("의자", 20, new int[][]{{0,0},{0,1},{1,1}}));
        ITEMS.put("table", new Item("테이블", 30, new int[][]{{0,0},{1,0},{2,0},{1,1}}));
        ITEMS.put("lantern", new Item("랜턴", 25, rect(1,2)));
        ITEMS.put("rug", new Item("러그", 18, new int[][]{{0,0},{0,1},{1,1},{1,2}}));
        ITEMS.put("meal", new Item("라면 재료", 20, rect(1,1)));
    }
    static int[][] rect(int w,int h) {
        var cells=new int[w*h][2];int i=0;
        for(int y=0;y<h;y++)for(int x=0;x<w;x++)cells[i++]=new int[]{x,y};
        return cells;
    }
    static List<Map<String,Object>> catalog() {
        return ITEMS.entrySet().stream().map(e -> Map.<String,Object>of("id",e.getKey(),"name",e.getValue().name(),
                "price",e.getValue().price(),"cells",e.getValue().cells(),"stackable",CampsiteCatalog.surface(e.getKey()).get("stackable"),"can_place_on_table",Boolean.TRUE.equals(CampsiteCatalog.surface(e.getKey()).get("can_place_on_table")),"surface_height",CampsiteCatalog.surface(e.getKey()).getOrDefault("surface_height",0),"rotation_step_degrees",90,"allowed_rotations",List.of(0,90,180,270))).toList();
    }
    static Map<String,Object> initialState() { return upgrade(PrototypeRules.legacyInitialState()); }
    static Map<String,Object> upgrade(Map<String,Object> current) {
        var s=PrototypeRules.copy(current);
        s.put("mvp_version",1);s.put("item_catalog",catalog());
        var inventory=new ArrayList<>(List.of("tent","stove"));
        if(current.get("packed") instanceof List<?> packed)for(Object id:packed)if(id instanceof String name&&ITEMS.containsKey(name)&&!name.equals("meal")&&!inventory.contains(name))inventory.add(name);
        s.put("owned",inventory);
        s.put("cargo",new LinkedHashMap<>());s.put("field",new LinkedHashMap<>());
        s.put("place","");s.put("outfit","basic");s.put("camp_day",0);s.put("camp_minute",960);
        s.put("pack_remaining_ms",45000);s.put("pack_started",false);s.put("pack_finished",false);
        s.put("packing_result",new ArrayList<>());s.put("lost",new ArrayList<>());
        s.put("meal_owned",false);s.put("cooked",false);s.put("eaten",false);s.put("cooking",0);
        s.put("rested",false);s.put("camp_elapsed_ms",0);s.put("status_note","");
        s.put("week_start_money",s.get("money"));s.put("week_spent",0);s.put("week_income",0);
        s.put("weather",forecast(((Number)s.get("week")).intValue()));
        if ("shopping".equals(s.get("phase")))s.put("phase","place");
        return s;
    }
    static List<Map<String,Object>> forecast(int week) {
        var days=new ArrayList<Map<String,Object>>();
        // 게임 날짜별로 재현되는 테스트 예보. 실제 날짜나 외부 API를 사용하지 않는다.
        for(int day=0;day<7;day++) {
            var weather=List.of("sun","cloud","rain").get(Math.floorMod(week+day*2,3));
            days.add(Map.of("date",(week-1)*7+day+1,"day",day,"weather",weather));
        }
        return days;
    }
    @SuppressWarnings("unchecked") static List<String> owned(Map<String,Object>s){return (List<String>)s.get("owned");}
    @SuppressWarnings("unchecked") static Map<String,Object> grid(Map<String,Object>s,String key){return (Map<String,Object>)s.get(key);}
    static int n(Map<String,Object>s,String k){return ((Number)s.get(k)).intValue();}
    static void add(Map<String,Object>s,String k,int delta){s.put(k,n(s,k)+delta);}
    static void need(boolean condition,String message){if(!condition)throw new IllegalArgumentException(message);}
    static boolean camping(String phase){return Set.of("setup","free","cooking","meal_ready","teardown").contains(phase);}
    static List<String> available(Map<String,Object>s) {
        if ("return_pack".equals(s.get("phase"))) {
            @SuppressWarnings("unchecked") var candidates=(List<String>)s.get("return_candidates");
            return new ArrayList<>(candidates);
        }
        var result=new ArrayList<>(owned(s));if(Boolean.TRUE.equals(s.get("meal_owned")))result.add("meal");return result;
    }
    static String weather(Map<String,Object>s) {
        var days=forecast(n(s,"week"));return (String)days.get(n(s,"camp_day")==0?5:6).get("weather");
    }
    static boolean suitable(Map<String,Object>s) {
        var rain=weather(s).equals("rain");return rain?"rain".equals(s.get("outfit")):!"sun".equals(weather(s))||"basic".equals(s.get("outfit"));
    }
    static void spendStamina(Map<String,Object>s,int base){s.put("stamina",Math.max(0,n(s,"stamina")-base*(suitable(s)?1:3)));}
    static void charge(Map<String,Object>s,int amount) {
        need(n(s,"money")>=amount,"소지금이 부족해요.");
        add(s,"money",-amount);add(s,"week_spent",amount);
    }
    static int integer(Map<String,Object>body,String key,int min,int max) {
        Object value=body.get(key);
        need(value instanceof Integer || value instanceof Long,"배치 값이 올바르지 않아요.");
        long number=((Number)value).longValue();need(number>=min&&number<=max,"배치 범위를 확인해 주세요.");return (int)number;
    }
    static int[][] footprint(String id,boolean rotated) {
        return footprint(id,rotated?90:0);
    }
    static int[][] footprint(String id,int angle) {
        var cells=Arrays.stream(ITEMS.get(id).cells()).map(int[]::clone).toArray(int[][]::new);
        for(int turn=0;turn<angle/90;turn++) {
            int height=Arrays.stream(cells).mapToInt(c->c[1]).max().orElse(0)+1;
            cells=Arrays.stream(cells).map(c->new int[]{height-1-c[1],c[0]}).toArray(int[][]::new);
        }
        return cells;
    }
    @SuppressWarnings("unchecked") static void place(Map<String,Object>s,String id,Map<String,Object>body,String zone) {
        need(ITEMS.containsKey(id),"알 수 없는 물건이에요.");
        var target=grid(s,zone);boolean field=zone.equals("field");
        if(field) need(grid(s,"cargo").containsKey(id)&&!id.equals("meal"),"차에 실은 장비만 설치할 수 있어요.");
        else if ("return_pack".equals(s.get("phase")))need(available(s).contains(id)&&!grid(s,"field").containsKey(id),"철거한 물건만 적재할 수 있어요.");
        else need(available(s).contains(id),"보유한 물건만 적재할 수 있어요.");
        int x=integer(body,"x",0,15),y=integer(body,"y",0,15);
        need(body.getOrDefault("rotated",false) instanceof Boolean,"회전 값이 올바르지 않아요.");
        int angle=requestedRotation(body);boolean rotated=angle%180!=0;
        if(!body.containsKey("rotation_degrees")&&target.get(id) instanceof Map<?,?> old) {
            @SuppressWarnings("unchecked") var previous=(Map<String,Object>)old;
            if(angle%180==fieldRotation(previous)%180)angle=fieldRotation(previous);
        }
        int width=field?(s.get("place").equals("pine")?10:8):6,height=field?(s.get("place").equals("pine")?7:6):5;
        var occupied=new HashSet<String>();
        for(var e:target.entrySet()) {
            if(e.getKey().equals(id))continue;
            var p=(Map<String,Object>)e.getValue();
            for(var c:footprint(e.getKey(),fieldRotation(p)))
                occupied.add((n(p,"x")+c[0])+":"+(n(p,"y")+c[1]));
        }
        for(var c:footprint(id,angle)) {
            int px=x+c[0],py=y+c[1];
            need(px<width&&py<height,"물건이 격자 밖으로 나가요.");
            need(!occupied.contains(px+":"+py),"다른 물건과 겹쳐요.");
            need(!field||!s.get("place").equals("pine")||!(px<2&&py<2),"나무가 있는 칸에는 놓을 수 없어요.");
        }
        boolean newItem=!target.containsKey(id);target.put(id,new LinkedHashMap<>(Map.of("x",x,"y",y,"rotated",rotated,"rotation_degrees",angle)));
        if(field&&newItem)spendStamina(s,1);
    }
    static double coordinate(Map<String,Object>body,String key,double min,double max) {
        Object value=body.get(key);need(value instanceof Number,"위치 값을 확인해 주세요.");
        double n=((Number)value).doubleValue();need(Double.isFinite(n)&&n>=min&&n<=max,"캠핑장 배치 범위를 벗어났어요.");return n;
    }
    static double[] bounds(String id,boolean rotated) {
        double[] b=switch(id){case "tent"->new double[]{2.0,1.8,2.0};case "table"->new double[]{2.1,.9,1.4};
            case "chair"->new double[]{1.0,1.2,1.0};case "stove"->new double[]{1.4,.65,.7};
            case "lantern"->new double[]{.5,1.0,.7};default->new double[]{1.4,.06,2.1};};
        return rotated?new double[]{b[2],b[1],b[0]}:b;
    }
    static int fieldRotation(Map<String,Object> value) {
        Object angle=value.get("rotation_degrees");
        return angle instanceof Number?((Number)angle).intValue():Boolean.TRUE.equals(value.get("rotated"))?90:0;
    }
    static boolean quarterTurn(Map<String,Object> value) {return fieldRotation(value)%180!=0;}
    static int requestedRotation(Map<String,Object> body) {
        need(body.getOrDefault("rotated",false) instanceof Boolean,"회전 값을 확인해 주세요.");
        if(!body.containsKey("rotation_degrees"))return fieldRotation(body);
        Object value=body.get("rotation_degrees");
        need(value instanceof Integer||value instanceof Long,"회전은 90도 단위로 선택해 주세요.");
        long angle=((Number)value).longValue();
        need(angle==0||angle==90||angle==180||angle==270,"회전은 0·90·180·270도만 가능해요.");
        return (int)angle;
    }
    @SuppressWarnings("unchecked") static void placeField(Map<String,Object>s,String id,Map<String,Object>body) {
        if ("z_up".equals(body.get("coordinate_system"))) {
            var converted=new LinkedHashMap<>(body);converted.put("y",body.get("z"));converted.put("z",body.get("y"));body=converted;
        } else need(!body.containsKey("coordinate_system"),"좌표 기준을 확인해 주세요.");
        need(ITEMS.containsKey(id)&&!id.equals("meal")&&grid(s,"cargo").containsKey(id),"실어 온 장비만 배치할 수 있어요.");
        int rotation=requestedRotation(body);
        if(!body.containsKey("rotation_degrees")&&grid(s,"field").get(id) instanceof Map<?,?> old) {
            @SuppressWarnings("unchecked") var previous=(Map<String,Object>)old;
            if(rotation%180==fieldRotation(previous)%180)rotation=fieldRotation(previous);
        }
        boolean rotated=rotation%180!=0;double[] b=bounds(id,rotated);
        var area=CampsiteCatalog.area((String)s.get("place"));
        double minX=CampsiteCatalog.axis(area,"min",0),minZ=CampsiteCatalog.axis(area,"min",2),width=CampsiteCatalog.axis(area,"max",0),depth=CampsiteCatalog.axis(area,"max",2);
        double x=coordinate(body,"x",minX+b[0]/2,width-b[0]/2),y=coordinate(body,"y",0,3),z=coordinate(body,"z",minZ+b[2]/2,depth-b[2]/2);
        for(var blocked:CampsiteCatalog.blocked((String)s.get("place"))) {
            boolean intersects=x+b[0]/2>CampsiteCatalog.axis(blocked,"min",0)&&x-b[0]/2<CampsiteCatalog.axis(blocked,"max",0)
                &&z+b[2]/2>CampsiteCatalog.axis(blocked,"min",2)&&z-b[2]/2<CampsiteCatalog.axis(blocked,"max",2);
            need(!intersects,blocked.get("name")+"에는 놓을 수 없어요.");
        }
        var field=grid(s,"field");
        if(y>.02) {
            need(Boolean.TRUE.equals(CampsiteCatalog.surface(id).get("can_place_on_table")),"이 장비는 바닥에만 놓을 수 있어요.");
            boolean supported=false;
            for(var entry:field.entrySet()) {
                if(entry.getKey().equals(id)||!Boolean.TRUE.equals(CampsiteCatalog.surface(entry.getKey()).get("stackable")))continue;
                var support=(Map<String,Object>)entry.getValue();var top=bounds(entry.getKey(),quarterTurn(support));
                double height=((Number)support.get("y")).doubleValue()+((Number)CampsiteCatalog.surface(entry.getKey()).get("surface_height")).doubleValue();
                if(Math.abs(y-height)<.02&&Math.abs(x-((Number)support.get("x")).doubleValue())+b[0]/2<=top[0]/2+.01
                    &&Math.abs(z-((Number)support.get("z")).doubleValue())+b[2]/2<=top[2]/2+.01){supported=true;y=height;break;}
            }
            need(supported,"물건 전체를 올릴 수 있는 받침 위에 놓아 주세요.");
        } else y=0;
        if(Boolean.TRUE.equals(CampsiteCatalog.surface(id).get("stackable"))&&field.containsKey(id))need(!hasSupportedItems(field,id),"받침 위 물건을 먼저 내려 주세요.");
        for(var e:field.entrySet()) {
            if(e.getKey().equals(id))continue;
            var p=(Map<String,Object>)e.getValue();var q=bounds(e.getKey(),quarterTurn(p));
            double px=((Number)p.get("x")).doubleValue(),py=((Number)p.get("y")).doubleValue(),pz=((Number)p.get("z")).doubleValue();
            boolean overlap=Math.abs(x-px)<(b[0]+q[0])/2-.02&&Math.abs(z-pz)<(b[2]+q[2])/2-.02&&y<py+q[1]-.02&&y+b[1]>py+.02;
            need(!overlap,"다른 장비와 겹쳐요. 빈 곳으로 옮겨 주세요.");
        }
        boolean isNew=!field.containsKey(id);field.put(id,new LinkedHashMap<>(Map.of("x",x,"y",y,"z",z,"rotated",rotated,"rotation_degrees",rotation)));
        if(isNew)spendStamina(s,1);
    }
    @SuppressWarnings("unchecked") static boolean hasSupportedItems(Map<String,Object>field,String id) {
        return field.entrySet().stream().anyMatch(e->!e.getKey().equals(id)&&((Number)((Map<String,Object>)e.getValue()).get("y")).doubleValue()>.02);
    }
    static void removeField(Map<String,Object>s,String id) {
        var field=grid(s,"field");
        need(!Boolean.TRUE.equals(CampsiteCatalog.surface(id).get("stackable"))||!hasSupportedItems(field,id),"받침 위 물건을 먼저 내려 주세요.");
        field.remove(id);
    }
    static void finishPacking(Map<String,Object>s) {
        boolean returning=s.get("phase").equals("return_pack");
        var missed=new ArrayList<>(available(s));missed.removeAll(grid(s,"cargo").keySet());
        s.put("packing_result",missed);s.put("pack_finished",true);s.put("pack_started",false);
        if(returning){owned(s).removeAll(missed);if(missed.contains("meal"))s.put("meal_owned",false);s.put("lost",missed);s.put("phase","settlement");}
        else {s.put("phase","setup");s.put("camp_day",0);s.put("camp_minute",960);s.put("field",new LinkedHashMap<>());s.put("stamina",Math.max(40,n(s,"stamina")));}
    }
    static void tick(Map<String,Object>s,Map<String,Object>body) {
        int elapsed=integer(body,"elapsed_ms",0,2000);String phase=(String)s.get("phase");
        if(phase.equals("work")) {
            DocumentWork.tick(s,elapsed);
        } else if(Set.of("packing","return_pack").contains(phase)&&Boolean.TRUE.equals(s.get("pack_started"))) {
            s.put("pack_remaining_ms",Math.max(0,n(s,"pack_remaining_ms")-elapsed));
            if(n(s,"pack_remaining_ms")==0)finishPacking(s);
        } else if(camping(phase)) {
            int previous=n(s,"camp_elapsed_ms");add(s,"camp_elapsed_ms",elapsed);
            add(s,"camp_minute",(n(s,"camp_elapsed_ms")/1000)-(previous/1000));
            if(n(s,"camp_elapsed_ms")/10000>previous/10000)spendStamina(s,1);
            if(n(s,"stamina")==0) {
                s.put("status_note",n(s,"camp_day")==0?"체력이 바닥났어요. 잠을 자고 회복해요.":"체력이 바닥났어요. 장비를 정리하고 돌아가요.");
                s.put("phase",n(s,"camp_day")==0?"sleep_required":"teardown");
            }
        }
    }
    static Map<String,Object> transition(Map<String,Object>current,String command,String choice,Map<String,Object>body) {
        var s=PrototypeRules.copy(current);String phase=(String)s.get("phase");
        if(command.equals("tick")){tick(s,body);return s;}
        if(phase.equals("character")&&command.equals("select_character")) {
            need(Set.of("male","female").contains(choice),"캐릭터를 선택해 주세요.");s.put("character_id",choice);s.put("phase","work");
        } else if(phase.equals("work")&&command.equals("office_start")) {
            DocumentWork.start(s);
        } else if(phase.equals("work")&&command.equals("office_pause")) {
            if(body.containsKey("elapsed_ms"))DocumentWork.tick(s,integer(body,"elapsed_ms",0,2000));
            DocumentWork.task(s).put("active",false);
        } else if(phase.equals("work")&&command.equals("office_review")) {
            DocumentWork.review(s,choice,body);
        } else if(phase.equals("work")&&command.equals("office_finish")) {
            need(DocumentWork.remaining(DocumentWork.task(s))==0,"20초 업무 시간이 끝나면 퇴근할 수 있어요.");
            finishWork(s);
        } else if(phase.equals("work")&&command.equals("work")) {
            need(!s.containsKey("office_task"),"시작한 서류 검토 업무를 먼저 마쳐 주세요.");
            finishWork(s);
        } else if(phase.equals("place")&&command.equals("choose_place")) {
            need(Set.of("lake","pine").contains(choice),"장소를 골라 주세요.");charge(s,choice.equals("lake")?15:30);s.put("place",choice);s.put("phase","equipment");
        } else if(phase.equals("equipment")&&command.equals("buy_item")) {
            need(ITEMS.containsKey(choice)&&!choice.equals("meal"),"구매할 장비를 확인해 주세요.");
            need(!owned(s).contains(choice),"이미 보유한 장비예요.");charge(s,ITEMS.get(choice).price());owned(s).add(choice);
        } else if(phase.equals("equipment")&&command.equals("shop_done"))s.put("phase","prepare");
        else if(phase.equals("prepare")&&command.equals("buy_meal")) {
            need(!Boolean.TRUE.equals(s.get("meal_owned")),"이번 캠핑 음식은 이미 준비했어요.");charge(s,20);s.put("meal_owned",true);
        } else if(phase.equals("prepare")&&command.equals("set_clothes")) {
            need(Set.of("basic","rain").contains(choice),"옷을 선택해 주세요.");s.put("outfit",choice);
        } else if(phase.equals("prepare")&&command.equals("prepare_done")) {
            s.put("phase","packing");s.put("cargo",new LinkedHashMap<>());s.put("pack_started",false);s.put("pack_finished",false);s.put("pack_remaining_ms",45000);
        } else if(Set.of("packing","return_pack").contains(phase)&&command.equals("start_pack")) {
            need(!Boolean.TRUE.equals(s.get("pack_started")),"이미 적재 중이에요.");s.put("pack_started",true);
        } else if(Set.of("packing","return_pack").contains(phase)&&command.equals("finish_pack")) {
            need(Boolean.TRUE.equals(s.get("pack_started")),"짐 싸기를 먼저 시작해 주세요.");
            var missed=new ArrayList<>(available(s));missed.removeAll(grid(s,"cargo").keySet());
            need(!phase.equals("return_pack")||missed.isEmpty()||Boolean.TRUE.equals(body.get("confirm_loss")),"남겨질 물건을 확인한 뒤 귀가해 주세요.");
            finishPacking(s);
        } else if(Set.of("packing","return_pack").contains(phase)&&Set.of("place_item","remove_item").contains(command)) {
            need(Boolean.TRUE.equals(s.get("pack_started")),"짐 싸기를 먼저 시작해 주세요.");
            if(command.equals("place_item"))place(s,choice,body,"cargo");else grid(s,"cargo").remove(choice);
        } else if(Set.of("setup","free").contains(phase)&&command.equals("place_item"))placeField(s,choice,body);
        else if(Set.of("setup","free").contains(phase)&&command.equals("remove_item"))removeField(s,choice);
        else if(phase.equals("setup")&&command.equals("setup_done"))s.put("phase","free");
        else if(phase.equals("free")&&command.equals("edit_camp"))s.put("phase","setup");
        else if(phase.equals("free")&&command.equals("cook_begin")) {
            need(Boolean.TRUE.equals(s.get("meal_owned"))&&grid(s,"cargo").containsKey("meal"),"실어 온 라면 재료가 필요해요.");
            need(grid(s,"field").containsKey("stove"),"버너를 먼저 설치해 주세요.");
            if(Boolean.TRUE.equals(s.get("cooked")))s.put("phase","meal_ready");else{s.put("cooking",0);s.put("phase","cooking");}
        } else if(phase.equals("cooking")&&command.equals("cook")) {
            add(s,"cooking",1);if(n(s,"cooking")==3){s.put("cooked",true);s.put("phase","meal_ready");}
        } else if(phase.equals("meal_ready")&&command.equals("eat")) {
            s.put("meal_owned",false);grid(s,"cargo").remove("meal");s.put("eaten",true);if(n(s,"camp_day")==0)s.put("camp_minute",Math.max(1080,n(s,"camp_minute")));s.put("stamina",Math.min(100,n(s,"stamina")+25));s.put("phase","free");
        } else if(phase.equals("free")&&command.equals("rest")) {
            need(!Boolean.TRUE.equals(s.get("rested")),"오늘은 충분히 쉬었어요.");s.put("rested",true);s.put("stamina",Math.min(100,n(s,"stamina")+15));add(s,"camp_minute",30);
        } else if(Set.of("free","sleep_required").contains(phase)&&command.equals("sleep")) {
            need(n(s,"camp_day")==0,"일요일에는 귀가를 준비해요.");s.put("camp_day",1);s.put("camp_minute",480);s.put("rested",false);s.put("stamina",Math.min(100,n(s,"stamina")+60));s.put("status_note","");s.put("phase","free");
        } else if(phase.equals("free")&&command.equals("leave_camp")) {
            need(n(s,"camp_day")==1,"토요일에는 캠프에서 하룻밤 쉬어요.");s.put("phase","teardown");
        } else if(phase.equals("teardown")&&command.equals("take_down")) {
            need(grid(s,"field").containsKey(choice),"철거할 장비를 선택해 주세요.");removeField(s,choice);spendStamina(s,1);
        } else if(phase.equals("teardown")&&command.equals("teardown_done")) {
            need(grid(s,"field").isEmpty(),"설치한 장비를 모두 철거해 주세요.");
            // 귀가는 현장에 가져온 물건만 대상으로 하며 집의 미적재품은 보존한다.
            var brought=new ArrayList<>(grid(s,"cargo").keySet());
            s.put("return_candidates",brought);s.put("cargo",new LinkedHashMap<>());s.put("phase","return_pack");
            s.put("pack_started",false);s.put("pack_finished",false);s.put("pack_remaining_ms",45000);
        } else if(phase.equals("settlement")&&command.equals("next_week")) {
            add(s,"week",1);s.put("day",0);s.put("phase","work");s.put("place","");s.put("field",new LinkedHashMap<>());s.put("cargo",new LinkedHashMap<>());
            s.put("cooked",false);s.put("eaten",false);s.put("cooking",0);s.put("rested",false);
            s.put("camp_elapsed_ms",0);s.put("status_note","");s.put("lost",new ArrayList<>());s.put("weather",forecast(n(s,"week")));
            s.put("week_start_money",s.get("money"));s.put("week_income",0);s.put("week_spent",0);
        } else throw new IllegalArgumentException("현재 단계에서 할 수 없는 행동이에요.");
        return s;
    }

    static void finishWork(Map<String,Object> s) {
        int pay=s.containsKey("office_task")?DocumentWork.pay(DocumentWork.task(s)):DocumentWork.BASE_PAY;
        add(s,"money",pay);add(s,"week_income",pay);s.put("stamina",Math.max(0,n(s,"stamina")-6));add(s,"day",1);
        s.remove("office_task");s.remove("office_case");s.remove("office_remaining_ms");s.remove("office_pay");
        if(n(s,"day")==5)s.put("phase","place");
    }
}
