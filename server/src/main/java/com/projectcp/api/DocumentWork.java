package com.projectcp.api;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

/** 비교 가능한 원본/접수 서류를 생성하고 처리 진척을 서버에서 검증한다. */
final class DocumentWork {
    private DocumentWork() {}
    static final int SHIFT_MS=20_000;
    static final int BASE_PAY=10;
    private static final Map<String,String> FIELDS=Map.of("supplier","거래처","amount","금액","due","납기일");

    static int pay(Map<String,Object> task) {
        return ((Number)task.getOrDefault("earned",MvpRules.n(task,"index")*2)).intValue();
    }
    static int remaining(Map<String,Object> task) {
        return ((Number)task.getOrDefault("remaining_ms",SHIFT_MS)).intValue();
    }

    static void tick(Map<String,Object> state,int elapsed) {
        if(state.get("office_task") instanceof Map<?,?>) {
            var task=task(state);
            if(Boolean.TRUE.equals(task.get("active")))task.put("remaining_ms",Math.max(0,remaining(task)-elapsed));
        }
    }

    @SuppressWarnings("unchecked") static Map<String,Object> task(Map<String,Object> state) {
        Object raw=state.get("office_task");
        MvpRules.need(raw instanceof Map<?,?>,"서류 업무를 먼저 시작해 주세요.");
        var task=(Map<String,Object>)raw;
        MvpRules.need(Objects.equals(task.get("week"),state.get("week"))&&Objects.equals(task.get("day"),state.get("day")),"오늘의 업무를 다시 열어 주세요.");
        return task;
    }
    static Map<String,Object> document(Map<String,Object> state,int index) {
        int day=MvpRules.n(state,"day"),week=MvpRules.n(state,"week");
        String[] vendors={"솔숲상사","호수물류","새벽문구","주말공방"};
        int vendor=Math.floorMod(week+day+index,4),amount=12000+Math.floorMod(week*7+day*3+index*11,8)*1500;
        int due=10+Math.floorMod(week+day+index,14);
        var original=Map.<String,Object>of("supplier",vendors[vendor],"amount",amount,"due",due);
        var submitted=new LinkedHashMap<>(original);
        // Keep an already-open shift's papers stable across an update or reload.
        Object seed=task(state).get("case_seed");
        int difference=Math.floorMod(week+day*2+index,4);
        if(seed instanceof Number number)
            difference=new Random(number.longValue()+index*0x9E3779B97F4A7C15L).nextInt(4);
        switch(difference) {
            case 1 -> submitted.put("supplier",vendors[(vendor+1)%4]);
            case 2 -> submitted.put("amount",amount+1500);
            case 3 -> submitted.put("due",due+1);
            default -> { }
        }
        return Map.of("id","W"+week+"-D"+day+"-"+index,"order",original,"invoice",submitted);
    }
    static void start(Map<String,Object> state) {
        if(!state.containsKey("office_task"))state.put("office_task",new LinkedHashMap<>(Map.of(
            "week",state.get("week"),"day",state.get("day"),"index",0,"mistakes",0,"earned",0,"remaining_ms",SHIFT_MS,"active",true,"case_seed",ThreadLocalRandom.current().nextLong(),"feedback","거래처·금액·납기일을 대조해 주세요.")));
        task(state).put("active",true);
    }
    @SuppressWarnings("unchecked") static void review(Map<String,Object> state,String choice,Map<String,Object> body) {
        var task=task(state);MvpRules.need(Boolean.TRUE.equals(task.get("active")),"서류 업무를 다시 열어 주세요.");
        int index=MvpRules.n(task,"index");MvpRules.need(remaining(task)>0,"업무 시간이 끝났어요. 퇴근해 주세요.");
        var paper=document(state,index);
        MvpRules.need(Objects.equals(body.get("case_id"),paper.get("id")),"현재 서류를 다시 확인해 주세요.");
        MvpRules.need(Set.of("approve","revise").contains(choice),"결재 또는 보완 요청을 선택해 주세요.");
        var order=(Map<String,Object>)paper.get("order");var invoice=(Map<String,Object>)paper.get("invoice");
        String mismatch=FIELDS.keySet().stream().filter(key->!Objects.equals(order.get(key),invoice.get(key))).findFirst().orElse("");
        Object selected=body.get("field");
        if(choice.equals("revise"))
            MvpRules.need(selected instanceof String && FIELDS.containsKey(selected),"청구서에서 다른 항목을 먼저 표시해 주세요.");
        boolean correct=mismatch.isEmpty()?choice.equals("approve"):choice.equals("revise")&&mismatch.equals(selected);
        int award=correct?2:1;
        task.put("earned",pay(task)+award);
        task.put("index",index+1);
        if(!correct) {
            MvpRules.add(task,"mistakes",1);
            task.put("remaining_ms",Math.max(0,remaining(task)-2_000));
        }
        task.put("feedback",correct?"정확히 처리했어요 · +2원":"판정이 달랐어요 · +1원 · 시간 −2초");
    }

    static Map<String,Object> enrich(Map<String,Object> state) {
        if(!"work".equals(state.get("phase"))||!state.containsKey("office_task"))return state;
        var result=new LinkedHashMap<>(state);int index=MvpRules.n(task(state),"index");
        result.put("office_remaining_ms",remaining(task(state)));
        result.put("office_pay",pay(task(state)));
        if(remaining(task(state))>0)result.put("office_case",document(state,index));
        return result;
    }
}
