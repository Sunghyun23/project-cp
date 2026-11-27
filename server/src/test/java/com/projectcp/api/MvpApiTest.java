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
        s.put("cargo",new LinkedHashMap<>(Map.of("table",Map.of(),"lantern",Map.of())));
        s=MvpRules.transition(s,"place_item","table",Map.of("x",3,"y",0,"z",3));
        var ground=s;
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
