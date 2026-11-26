from django.test import TestCase
from rest_framework.test import APIClient
from .rules import initial_state, transition


class PrototypeTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        response = self.client.post("/api/v1/prototype/sessions/", {}, format="json")
        self.assertEqual(response.status_code, 201)
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + response.data["token"])
        self.saved = response.data

    def act(self, command, choice=""):
        response = self.client.post("/api/v1/prototype/actions/", {
            "command": command, "choice": choice, "version": self.saved["version"]
        }, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.saved = response.data

    def week(self, meal, improved=False):
        for _ in range(5):
            self.act("work")
        self.act("buy", meal)
        for gear in ("tent", "table", "chair"):
            self.act("pack", gear)
        self.act("gear", "improved" if improved else "basic")
        self.act("next")
        for _ in range(3):
            self.act("install")
        self.act("rest")
        self.assertEqual(self.saved["state"]["phase"], "free")
        self.act("next")
        if meal == "skewer":
            for ingredient in ("meat", "mushroom", "meat"):
                self.act("ingredient", ingredient)
        for _ in range(2 if improved else 3):
            self.act("cook")
        self.assertEqual(self.saved["state"]["phase"], "night")
        self.act("rest")
        self.assertEqual(self.saved["state"]["phase"], "night")
        self.act("next")
        self.act("breakfast")
        for _ in range(3):
            self.act("pack_up")
        self.assertEqual(self.saved["state"]["phase"], "settlement")
        self.act("next")

    def test_full_week_both_meals_and_reload(self):
        self.week("ramen")
        self.week("skewer", improved=True)
        reloaded = self.client.get("/api/v1/prototype/state/").data
        self.assertEqual(reloaded, self.saved)
        self.assertEqual(reloaded["state"]["week"], 3)
        self.assertEqual(len(reloaded["state"]["recipes"]), 2)

    def test_mastery_bonus_only_after_repeated_three_star_recipe(self):
        for _ in range(4):
            self.week("ramen", improved=True)
        self.assertEqual(self.saved["state"]["stars"], 4)

    def test_stale_action_does_not_apply_twice(self):
        self.act("work")
        response = self.client.post("/api/v1/prototype/actions/", {"command": "work", "version": 0}, format="json")
        self.assertEqual(response.status_code, 409)
        self.assertEqual(self.client.get("/api/v1/prototype/state/").data["state"]["day"], 1)

    def test_unknown_token_cannot_access_saved_progress(self):
        self.client.credentials(HTTP_AUTHORIZATION="Bearer invalid")
        self.assertEqual(self.client.get("/api/v1/prototype/state/").status_code, 401)

    def test_invalid_action_keeps_state_unchanged(self):
        response = self.client.post("/api/v1/prototype/actions/", {"command": "cook", "version": 0}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(self.client.get("/api/v1/prototype/state/").data, {"state": self.saved["state"], "version": 0})

    def test_packing_and_cooking_prerequisites(self):
        state = initial_state()
        state.update(phase="packing")
        with self.assertRaises(ValueError):
            transition(state, "next")
        state.update(phase="dinner", meal="skewer")
        with self.assertRaises(ValueError):
            transition(state, "cook")
