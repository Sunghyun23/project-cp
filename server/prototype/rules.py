"""프로토타입용 임시 수치. 최종 게임 밸런스가 아니다."""
from copy import deepcopy


def initial_state():
    return dict(week=1, day=0, phase="work", money=80, strength=50, luck=50,
                stamina=80, meal="", gear="basic", packed=[], cooking=0,
                ingredients=[], rested=False, job_done=False, stars=0, recipes={})


def transition(current, command, choice=""):
    s = deepcopy(current)
    phase = s["phase"]
    if phase == "work" and command == "job" and not s["job_done"]:
        s["money"] += 15
        s["stamina"] = max(0, s["stamina"] - 8)
        s["job_done"] = True
    elif phase == "work" and command == "work":
        s["money"] += 10
        s["stamina"] = max(0, s["stamina"] - 6)
        s["strength"] = max(0, s["strength"] - 2)
        s["luck"] = max(0, s["luck"] - 1)
        s["day"] += 1
        s["job_done"] = False
        if s["day"] == 5:
            s["phase"] = "shopping"
    elif phase == "shopping" and command == "buy" and choice in ("ramen", "skewer"):
        cost = 20 if choice == "ramen" else 25
        if s["money"] < cost:
            raise ValueError("재료를 살 돈이 부족해요.")
        s["money"] -= cost
        s["meal"] = choice
        s["phase"] = "packing"
    elif phase == "packing" and command == "pack" and choice in ("tent", "table", "chair"):
        if choice in s["packed"]:
            s["packed"].remove(choice)
        else:
            s["packed"].append(choice)
    elif phase == "packing" and command == "gear" and choice in ("basic", "improved"):
        s["gear"] = choice
    elif phase == "packing" and command == "next" and len(s["packed"]) == 3:
        s["phase"] = "setup"
        s["setup"] = 0
    elif phase == "setup" and command == "install":
        s["setup"] += 1
        s["stamina"] = max(0, s["stamina"] - 2)
        if s["setup"] == 3:
            s["phase"] = "free"
    elif phase in ("free", "night") and command == "rest" and not s["rested"]:
        s["stamina"] = min(100, s["stamina"] + (12 if s["gear"] == "improved" else 6))
        s["rested"] = True
    elif phase in ("free", "night") and command == "next":
        s["phase"] = "dinner" if phase == "free" else "breakfast"
        s["rested"] = False
    elif phase == "dinner" and command == "ingredient" and s["meal"] == "skewer" and choice in ("meat", "mushroom") and len(s["ingredients"]) < 3:
        s["ingredients"].append(choice)
    elif phase == "dinner" and command == "cook":
        if s["meal"] == "skewer" and len(s["ingredients"]) != 3:
            raise ValueError("꼬치 재료 세 개를 먼저 골라 주세요.")
        s["cooking"] += 1
        if s["cooking"] >= (2 if s["gear"] == "improved" else 3):
            key = s["meal"] + ":" + ",".join(sorted(s["ingredients"]))
            recipe = s["recipes"].setdefault(key, {"stars": 0, "mastery": 0})
            if recipe["stars"] >= 3:
                recipe["mastery"] = min(3, recipe["mastery"] + 1)
            bonus = 8 if s["gear"] == "improved" else 0
            s["stamina"] = min(100, s["stamina"] + 20 + bonus + recipe["mastery"])
            s["strength"] = min(100, s["strength"] + 5 + s["ingredients"].count("meat") * 3)
            s["luck"] = min(100, s["luck"] + 5 + s["ingredients"].count("mushroom") * 3)
            recipe["stars"] = max(recipe["stars"], 3 if bonus else 2)
            s["stars"] = recipe["stars"] + int(recipe["mastery"] == 3)
            s["phase"] = "night"
    elif phase == "breakfast" and command == "breakfast":
        s["stamina"] = min(100, s["stamina"] + 10)
        s["phase"] = "teardown"
        s["teardown"] = 0
    elif phase == "teardown" and command == "pack_up":
        s["teardown"] += 1
        if s["teardown"] == 3:
            s["phase"] = "settlement"
    elif phase == "settlement" and command == "next":
        s.update(week=s["week"] + 1, day=0, phase="work", meal="", packed=[],
                 cooking=0, ingredients=[], rested=False, job_done=False)
    else:
        raise ValueError("현재 단계에서 할 수 없는 행동이에요.")
    return s
