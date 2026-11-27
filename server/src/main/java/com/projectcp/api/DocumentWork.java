package com.projectcp.api;

import java.util.*;

/** 비교 가능한 원본/접수 서류를 생성하고 처리 진척을 서버에서 검증한다. */
final class DocumentWork {
    private DocumentWork() {}
    static final int TOTAL=6;
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
        switch(Math.floorMod(week+day*2+index,4)) {
            case 1 -> submitted.put("supplier",vendors[(vendor+1)%4]);
            case 2 -> submitted.put("amount",amount+1500);
            case 3 -> submitted.put("due",due+1);
            default -> { }
        }
        return Map.of("id","W"+week+"-D"+day+"-"+index,"order",original,"invoice",submitted);
    }
    static void start(Map<String,Object> state) {
        if(!state.containsKey("office_task"))state.put("office_task",new LinkedHashMap<>(Map.of(
            "week",state.get("week"),"day",state.get("day"),"index",0,"mistakes",0,"active",true,"feedback","거래처·금액·납기일을 대조해 주세요.")));
        task(state).put("active",true);
    }
    @SuppressWarnings("unchecked") static void review(Map<String,Object> state,String choice,Map<String,Object> body) {
        var task=task(state);MvpRules.need(Boolean.TRUE.equals(task.get("active")),"서류 업무를 다시 열어 주세요.");
        int index=MvpRules.n(task,"index");MvpRules.need(index<TOTAL,"모든 서류를 검토했어요. 퇴근해 주세요.");
        var paper=document(state,index);
        MvpRules.need(Objects.equals(body.get("case_id"),paper.get("id")),"현재 서류를 다시 확인해 주세요.");
        MvpRules.need(Set.of("approve","revise").contains(choice),"결재 또는 보완 요청을 선택해 주세요.");
        var order=(Map<String,Object>)paper.get("order");var invoice=(Map<String,Object>)paper.get("invoice");
        boolean valid=order.equals(invoice),correct=choice.equals(valid?"approve":"revise");
        if(correct) {task.put("index",index+1);task.put("feedback",valid?"결재 완료 · 다음 서류를 확인해요.":"보완 요청 완료 · 차이를 정확히 찾았어요.");}
        else {
            MvpRules.add(task,"mistakes",1);
            String reason="모든 항목이 일치해요. 결재할 수 있어요.";
            for(String key:List.of("supplier","amount","due"))if(!Objects.equals(order.get(key),invoice.get(key))) {
                reason=Map.of("supplier","거래처","amount","금액","due","납기일").get(key)+" 항목이 원본과 달라요. 보완 요청이 필요해요.";break;
            }
            task.put("feedback",reason); // 오답은 같은 서류를 유지하며 급여를 지급하지 않는다.
        }
    }
    static Map<String,Object> enrich(Map<String,Object> state) {
        if(!"work".equals(state.get("phase"))||!state.containsKey("office_task"))return state;
        var result=new LinkedHashMap<>(state);int index=MvpRules.n(task(state),"index");
        result.put("office_total",TOTAL);
        if(index<TOTAL)result.put("office_case",document(state,index));
        return result;
    }
}
