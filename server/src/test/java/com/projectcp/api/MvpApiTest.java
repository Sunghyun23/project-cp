package com.projectcp.api;

import java.net.URI;
import java.net.http.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT)
class MvpApiTest {
    @LocalServerPort int port;
    @Autowired JsonMapper json;
    final HttpClient http=HttpClient.newHttpClient();
    record Reply(int status,Map<String,Object> data) {}
    Reply call(String method,String path,String token,Map<String,Object> body)throws Exception {
        var b=HttpRequest.newBuilder(URI.create("http://localhost:"+port+"/api/v1/prototype/"+path));
        if(token!=null)b.header("Authorization","Bearer "+token);
        if(body!=null)b.header("Content-Type","application/json");
        b.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        var r=http.send(b.build(),HttpResponse.BodyHandlers.ofString());
        return new Reply(r.statusCode(),json.readValue(r.body(),new TypeReference<Map<String,Object>>(){}));
    }
    class Player {
        String token;Map<String,Object> saved;
        Player()throws Exception {var r=call("POST","sessions/",null,Map.of());assertEquals(201,r.status());token=(String)r.data().get("token");saved=r.data();}
        @SuppressWarnings("unchecked") Map<String,Object> s(){return (Map<String,Object>)saved.get("state");}
        void act(String command,String choice,Map<String,Object> extra)throws Exception {
            var body=new LinkedHashMap<>(extra);body.put("command",command);body.put("choice",choice);body.put("version",saved.get("version"));
            var r=call("POST","actions/",token,body);assertEquals(200,r.status(),r.data().toString());saved=r.data();
        }
        void act(String command)throws Exception{act(command,"",Map.of());}
        void act(String command,String choice)throws Exception{act(command,choice,Map.of());}
        void place(String id,int x,int y,boolean rotate)throws Exception{act("place_item",id,Map.of("x",x,"y",y,"rotated",rotate));}
        void world(String id,double x,double y,double z)throws Exception{act("place_item",id,Map.of("x",x,"y",y,"z",z,"rotated",false));}
        void expire()throws Exception{for(int i=0;i<23;i++)act("tick","",Map.of("elapsed_ms",2000));}
        void prepare(boolean food)throws Exception {
            act("select_character","male");for(int i=0;i<5;i++)act("work");assertEquals("place",s().get("phase"));
            act("choose_place","lake");act("buy_item","chair");act("shop_done");
            if(food)act("buy_meal");act("set_clothes","rain");act("prepare_done");act("start_pack");
        }
    }
    @SuppressWarnings("unchecked") String officeAnswer(Player p) {
        var paper=(Map<String,Object>)p.s().get("office_case");
        return paper.get("order").equals(paper.get("invoice"))?"approve":"revise";
    }
    @SuppressWarnings("unchecked") Map<String,Object> officeBody(Player p) {
        var paper=(Map<String,Object>)p.s().get("office_case");
        var order=(Map<?,?>)paper.get("order");
        var invoice=(Map<?,?>)paper.get("invoice");
        var field=List.of("supplier","amount","due").stream().filter(key->!Objects.equals(order.get(key),invoice.get(key))).findFirst().orElse("amount");
        return Map.of("case_id",paper.get("id"),"field",field);
    }
    void expireOfficeShift(Player p)throws Exception {
        for(int ms=((Number)p.s().get("office_remaining_ms")).intValue();ms>0;ms-=2000)
            p.act("tick","",Map.of("elapsed_ms",Math.min(ms,2000)));
    }
    @Test void officeWorkPaysForEachSubmissionAndExpires()throws Exception {
        var p=new Player();p.act("select_character","female");int money=((Number)p.s().get("money")).intValue();
        p.act("office_start");
        assertEquals(20_000,p.s().get("office_remaining_ms"));
        var current=officeBody(p);
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","office_finish","version",p.saved.get("version"))).status());
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","office_review","choice","revise","case_id",current.get("case_id"),"version",p.saved.get("version"))).status());
        var wrong=new HashMap<>(current);
        wrong.put("field",current.get("field").equals("amount")?"due":"amount");
        p.act("office_review","revise",wrong);
        assertEquals(1,((Map<?,?>)p.s().get("office_task")).get("index"));
        assertEquals(1,p.s().get("office_pay"));
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","office_review","choice","approve","case_id",current.get("case_id"),"version",p.saved.get("version"))).status());
        p.act("office_review",officeAnswer(p),officeBody(p));
        assertEquals(3,p.s().get("office_pay"));
        p.act("office_pause","",Map.of("elapsed_ms",500));
        p.act("tick","",Map.of("elapsed_ms",2000));
        assertEquals(19_500,p.s().get("office_remaining_ms"));
        assertEquals(p.saved,call("GET","state/",p.token,null).data());
        p.act("office_start");expireOfficeShift(p);
        assertFalse(p.s().containsKey("office_case"));
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","office_review","choice","approve","case_id","expired","version",p.saved.get("version"))).status());
        assertEquals(money,p.s().get("money"));
        var version=p.saved.get("version");p.act("office_finish");
        assertEquals(money+3,p.s().get("money"));assertEquals(1,p.s().get("day"));assertFalse(p.s().containsKey("office_task"));
        assertEquals(409,call("POST","actions/",p.token,Map.of("command","office_finish","version",version)).status());
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","office_finish","version",p.saved.get("version"))).status());
    }
    @Test void officeWorkCompletesFiveDaysWithoutFixedDocumentQuota()throws Exception {
        var p=new Player();p.act("select_character","male");
        for(int day=0;day<5;day++) {
            p.act("office_start");
            assertEquals(400,call("POST","actions/",p.token,Map.of("command","office_review","choice","approve","case_id","forged","index",6,"version",p.saved.get("version"))).status());
            for(int i=0;i<7;i++)p.act("office_review",officeAnswer(p),officeBody(p));
            expireOfficeShift(p);
            p.act("office_finish");
        }
        assertEquals("place",p.s().get("phase"));assertEquals(150,p.s().get("money"));assertEquals(50,p.s().get("stamina"));
    }
    @Test void eachSitePublishesTrustedCoordinatesAndChecksItsForbiddenRegions()throws Exception {
        var p=new Player();p.prepare(false);
        @SuppressWarnings("unchecked") var published=(Map<String,Object>)p.s().get("placement_site");
        assertEquals(CampsiteCatalog.site("lake"),published);
        assertEquals(8.0,CampsiteCatalog.axis(CampsiteCatalog.area("lake"),"max",0));
        assertEquals(10.0,CampsiteCatalog.axis(CampsiteCatalog.area("pine"),"max",0));
        var source=PrototypeRules.copy(p.s());
        source.put("phase","setup");source.put("place","pine");
        source.put("cargo",Map.of("lantern",Map.of()));source.put("field",new LinkedHashMap<>());
        // 응답의 범위를 위조해도 서버의 장소 정의가 판정 기준이다.
        source.put("placement_site",Map.of("placement",Map.of("blocked",List.of())));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(source,"place_item","lantern",Map.of("x",1.0,"y",0.0,"z",1.0)));
        var saved=MvpRules.transition(source,"place_item","lantern",Map.of("x",2.0,"y",0.0,"z",2.0));
        assertTrue(((Map<?,?>)saved.get("field")).containsKey("lantern"));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(source,"place_item","lantern",Map.of("x",10.1,"y",0.0,"z",2.0)));
    }
    @Test void earlyDepartureAndReturnUseSamePackingResultsAndRequireLossConfirmation()throws Exception {
        var p=new Player();p.prepare(false);p.place("tent",0,0,false);
        p.act("finish_pack");assertEquals("setup",p.s().get("phase"));
        assertTrue(((Number)p.s().get("pack_remaining_ms")).intValue()>0);
        assertEquals(List.of("stove","chair"),p.s().get("packing_result"));
        p.act("setup_done");p.act("sleep");p.act("leave_camp");p.act("teardown_done");p.act("start_pack");
        var before=p.saved;
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","finish_pack","version",p.saved.get("version"))).status());
        assertEquals(before,call("GET","state/",p.token,null).data());
        p.act("finish_pack","",Map.of("confirm_loss",true));
        assertEquals("settlement",p.s().get("phase"));assertEquals(List.of("tent"),p.s().get("lost"));
        assertEquals(List.of("stove","chair"),p.s().get("owned"));
    }
    @Test void interlockingFootprintsLeaveRealHolesAndRotateInFourDirections()throws Exception {
        var p=new Player();p.prepare(true);p.place("tent",0,0,false);
        // 텐트 P 모양의 빈 칸에는 음식 1칸을 끼워 넣을 수 있다.
        p.place("meal",2,1,false);
        assertEquals(2,((Map<?,?>)p.s().get("cargo")).size());
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","place_item","choice","meal","version",p.saved.get("version"),"x",1,"y",1)).status());
        p.act("remove_item","meal");
        for(int angle:List.of(90,180,270,0)) {
            p.act("place_item","tent",Map.of("x",0,"y",0,"rotation_degrees",angle));
            assertEquals(angle,((Map<?,?>)((Map<?,?>)p.s().get("cargo")).get("tent")).get("rotation_degrees"));
            assertEquals(5,MvpRules.footprint("tent",angle).length);
            assertEquals(p.saved,call("GET","state/",p.token,null).data());
        }
        for(String id:List.of("tent","chair","table","rug")) {
            var shape=MvpRules.footprint(id,0);
            int w=Arrays.stream(shape).mapToInt(c->c[0]).max().orElseThrow()+1;
            int h=Arrays.stream(shape).mapToInt(c->c[1]).max().orElseThrow()+1;
            assertTrue(shape.length<w*h,id+" must have an interlocking silhouette");
        }
    }
    @Test void zUpDragRequestPreservesLegacyStorageAndPublishesStackableMetadata()throws Exception {
        var p=new Player();p.prepare(false);p.place("tent",0,0,false);p.place("stove",3,0,false);p.expire();
        p.act("place_item","stove",Map.of("x",4.0,"y",2.0,"z",0.0,"coordinate_system","z_up"));
        var saved=(Map<?,?>)((Map<?,?>)p.s().get("field")).get("stove");
        assertEquals(0.0,((Number)saved.get("y")).doubleValue());
        assertEquals(2.0,((Number)saved.get("z")).doubleValue());
        assertEquals("godot_y_up",p.s().get("field_coordinate_system"));
        assertEquals(true,CampsiteCatalog.surface("table").get("stackable"));
        for(String id:List.of("tent","chair","stove","lantern","rug"))assertEquals(false,CampsiteCatalog.surface(id).get("stackable"));
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","place_item","choice","stove","version",p.saved.get("version"),"x",4.0,"y",2.0,"z",.5,"coordinate_system","z_up")).status());
    }
    @Test void fourFieldDirectionsRoundTripAndLegacyMovesPreserveDirection()throws Exception {
        var p=new Player();p.prepare(false);p.place("tent",0,0,false);p.expire();
        for(int angle:List.of(0,90,180,270)) {
            p.act("place_item","tent",Map.of("x",3.0,"y",3.0,"z",0.0,"coordinate_system","z_up","rotation_degrees",angle));
            var pose=(Map<?,?>)((Map<?,?>)p.s().get("field")).get("tent");
            assertEquals(angle,pose.get("rotation_degrees"));assertEquals(angle%180!=0,pose.get("rotated"));
            assertEquals(p.saved,call("GET","state/",p.token,null).data());
        }
        p.act("place_item","tent",Map.of("x",3.25,"y",0.0,"z",3.0,"rotated",true));
        assertEquals(270,((Map<?,?>)((Map<?,?>)p.s().get("field")).get("tent")).get("rotation_degrees"));
        var before=p.saved;
        for(Object angle:List.of(45,-90,360,90.0,"90",false))assertEquals(400,call("POST","actions/",p.token,Map.of("command","place_item","choice","tent","version",p.saved.get("version"),"x",3,"y",0,"z",3,"rotation_degrees",angle)).status());
        assertEquals(before,call("GET","state/",p.token,null).data());
    }
    @Test void quarterTurnChecksBoundsAndRotatedSupportSurface() {
        var s=MvpRules.initialState();s.put("phase","setup");s.put("place","lake");s.put("cargo",Map.of("tent",Map.of(),"table",Map.of(),"stove",Map.of()));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(s,"place_item","tent",Map.of("x",.8,"y",0,"z",2,"rotation_degrees",0)));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(s,"place_item","tent",Map.of("x",.8,"y",0,"z",2,"rotation_degrees",90)));
        var turned=MvpRules.transition(s,"place_item","tent",Map.of("x",1,"y",0,"z",1,"rotation_degrees",90));
        assertEquals(90,((Map<?,?>)((Map<?,?>)turned.get("field")).get("tent")).get("rotation_degrees"));
        var table=MvpRules.transition(s,"place_item","table",Map.of("x",5,"y",0,"z",3,"rotation_degrees",90));
        var stacked=MvpRules.transition(table,"place_item","stove",Map.of("x",5,"y",.9,"z",3.6,"rotation_degrees",0));
        assertTrue(((Map<?,?>)stacked.get("field")).containsKey("stove"));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(stacked,"place_item","table",Map.of("x",5,"y",0,"z",3,"rotation_degrees",180)));
        var straight=MvpRules.transition(s,"place_item","table",Map.of("x",5,"y",0,"z",3,"rotation_degrees",0));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(straight,"place_item","stove",Map.of("x",5,"y",.9,"z",3.6,"rotation_degrees",0)));
    }
    @Test void completeTripConsumesFoodLosesOnlyUnpackedReturnGearAndPersists()throws Exception {
        var p=new Player();p.prepare(true);p.place("tent",0,0,false);p.place("stove",3,0,false);p.place("chair",3,1,false);p.place("meal",5,4,false);
        p.expire();assertEquals("setup",p.s().get("phase"));
        p.world("tent",1.5,0,1.0);p.world("stove",4,0,1.0);p.world("chair",4,0,3.0);p.act("setup_done");
        p.act("cook_begin");for(int i=0;i<3;i++)p.act("cook");assertEquals("meal_ready",p.s().get("phase"));
        p.act("eat");assertEquals(false,p.s().get("meal_owned"));assertFalse(((Map<?,?>)p.s().get("cargo")).containsKey("meal"));
        p.act("rest");p.act("sleep");assertEquals(1,p.s().get("camp_day"));p.act("leave_camp");
        for(String id:List.of("chair","stove","tent"))p.act("take_down",id);
        p.act("teardown_done");p.act("start_pack");p.place("tent",0,0,false);p.place("stove",3,0,false);p.expire();
        assertEquals("settlement",p.s().get("phase"));assertEquals(List.of("chair"),p.s().get("lost"));
        assertEquals(List.of("tent","stove"),p.s().get("owned"));assertEquals(75,p.s().get("money"));
        p.act("next_week");assertEquals(2,p.s().get("week"));assertEquals("male",p.s().get("character_id"));
        assertEquals(p.saved,call("GET","state/",p.token,null).data());
    }
    @Test void gridRejectsOverlapOutOfBoundsNonOwnedAndBadCoordinatesWithoutSaving()throws Exception {
        var p=new Player();p.prepare(false);p.place("tent",0,0,false);p.place("stove",3,0,false);var before=p.saved;
        for(var extra:List.of(Map.<String,Object>of("x",1,"y",0,"rotated",false),Map.<String,Object>of("x",5,"y",0,"rotated",true),Map.<String,Object>of("x",1.5,"y",0))) {
            var body=new LinkedHashMap<>(extra);body.putAll(Map.of("command","place_item","choice","tent","version",p.saved.get("version")));
            assertEquals(400,call("POST","actions/",p.token,body).status());
        }
        assertEquals(before,call("GET","state/",p.token,null).data());
        p.place("stove",3,0,true);assertTrue(((Map<?,?>)p.s().get("cargo")).containsKey("stove"));
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","place_item","choice","lantern","version",p.saved.get("version"),"x",4,"y",3)).status());
    }
    @Test void returnLossNeverRemovesItemsLeftAtHome()throws Exception {
        var p=new Player();p.prepare(false);p.place("tent",0,0,false);p.place("stove",3,0,false);p.expire();
        p.act("setup_done");p.act("sleep");p.act("leave_camp");p.act("teardown_done");p.act("start_pack");p.expire();
        assertEquals(List.of("chair"),p.s().get("owned"));assertEquals(List.of("tent","stove"),p.s().get("lost"));
    }
    @Test void forecastClothingPenaltyAndDailyWeatherAreConnected()throws Exception {
        var basic=new Player();basic.prepare(false);basic.expire();
        var rain=new Player();rain.prepare(false);rain.expire();
        // 별도 상태 단위 검사로 동일한 캠핑 시점·의상만 비교한다.
        var source=PrototypeRules.copy(basic.s());source.put("outfit","basic");
        var protectedState=PrototypeRules.copy(source);protectedState.put("outfit","rain");
        int start=((Number)source.get("stamina")).intValue();
        for(int i=0;i<5;i++){source=MvpRules.transition(source,"tick","",Map.of("elapsed_ms",2000));protectedState=MvpRules.transition(protectedState,"tick","",Map.of("elapsed_ms",2000));}
        assertEquals(start-3,source.get("stamina"));assertEquals(start-1,protectedState.get("stamina"));
        assertNotEquals(MvpRules.forecast(1).get(5).get("weather"),MvpRules.forecast(1).get(6).get("weather"));
        source.put("stamina",1);source.put("camp_elapsed_ms",8000);
        source=MvpRules.transition(source,"tick","",Map.of("elapsed_ms",2000));assertEquals("sleep_required",source.get("phase"));
        source=MvpRules.transition(source,"sleep","",Map.of());source.put("stamina",0);
        source=MvpRules.transition(source,"tick","",Map.of("elapsed_ms",1000));assertEquals("teardown",source.get("phase"));
    }
    @Test void fieldPlacementSupportsGroundAndTableButRejectsFloatingAndUnsupportedRemoval() {
        var s=MvpRules.initialState();s.put("phase","setup");s.put("place","lake");
        s.put("cargo",new LinkedHashMap<>(Map.of("table",Map.of(),"lantern",Map.of(),"chair",Map.of(),"rug",Map.of())));
        s=MvpRules.transition(s,"place_item","table",Map.of("x",3,"y",0,"z",3));
        var ground=s;
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(ground,"place_item","chair",Map.of("x",3,"y",.9,"z",3)));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(ground,"place_item","rug",Map.of("x",3,"y",0,"z",3)));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(ground,"place_item","lantern",Map.of("x",3,"y",1.5,"z",3)));
        s=MvpRules.transition(s,"place_item","lantern",Map.of("x",3,"y",.9,"z",3));
        var stacked=s;
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(stacked,"remove_item","table",Map.of()));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(stacked,"place_item","table",Map.of("x",5,"y",0,"z",3)));
        assertThrows(IllegalArgumentException.class,()->MvpRules.transition(stacked,"place_item","lantern",Map.of("x",6,"y",.9,"z",3)));
        s=MvpRules.transition(s,"place_item","lantern",Map.of("x",5,"y",0,"z",3));
        s=MvpRules.transition(s,"remove_item","table",Map.of());assertFalse(((Map<?,?>)s.get("field")).containsKey("table"));
    }

    @Test void duplicatePurchaseAndUnaffordablePlaceDoNotSpendMoney()throws Exception {
        var p=new Player();p.act("select_character","female");for(int i=0;i<5;i++)p.act("work");p.act("choose_place","pine");
        p.act("buy_item","chair");var before=p.saved;
        assertEquals(400,call("POST","actions/",p.token,Map.of("command","buy_item","choice","chair","version",p.saved.get("version"))).status());
        assertEquals(before,call("GET","state/",p.token,null).data());
    }
}
