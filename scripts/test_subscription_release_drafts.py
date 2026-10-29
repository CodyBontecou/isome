"""Offline integrity checks for the local 1.7.19 subscription copy drafts."""

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.7.19"
LISTINGS = ROOT / "metadata" / "whereday" / "version" / VERSION
BASELINE = LISTINGS.parent / "1.7.18"
DOCUMENTS = ROOT / "docs" / "release-drafts" / VERSION
LOCALES = {"ar-SA", "en-US", "es-ES", "fr-FR", "hi", "ja", "pt-BR", "ru", "zh-Hans"}
PRODUCT_IDS = {
    "com.bontecou.isome.individual.weekly",
    "com.bontecou.isome.individual.yearly",
    "com.bontecou.isome.family.weekly",
    "com.bontecou.isome.family.yearly",
}


class SubscriptionReleaseDraftTests(unittest.TestCase):
    def test_listing_locales_match_existing_release(self):
        self.assertEqual({p.stem for p in LISTINGS.glob("*.json")}, LOCALES)
        self.assertEqual({p.stem for p in BASELINE.glob("*.json")}, LOCALES)

    def test_listing_schema_lengths_and_preserved_fields(self):
        fields = {"description", "keywords", "marketingUrl", "promotionalText", "supportUrl", "whatsNew"}
        limits = {"description": 4000, "keywords": 100, "promotionalText": 170, "whatsNew": 4000}
        for locale in sorted(LOCALES):
            with self.subTest(locale=locale):
                listing = json.loads((LISTINGS / f"{locale}.json").read_text())
                baseline = json.loads((BASELINE / f"{locale}.json").read_text())
                self.assertEqual(set(listing), fields)
                for field, limit in limits.items():
                    self.assertIsInstance(listing[field], str)
                    self.assertGreater(len(listing[field]), 0)
                    self.assertLessEqual(len(listing[field]), limit, field)
                for field in ["keywords", "marketingUrl", "supportUrl"]:
                    self.assertEqual(listing[field], baseline[field], field)

    def test_listing_links_and_no_fixed_price_announcements(self):
        for locale in sorted(LOCALES):
            with self.subTest(locale=locale):
                listing = json.loads((LISTINGS / f"{locale}.json").read_text())
                self.assertIn("https://whereday.com/terms", listing["description"])
                self.assertIn("https://whereday.com/privacy", listing["description"])
                self.assertIn("EULA", listing["description"])
                for field in ["description", "promotionalText", "whatsNew"]:
                    self.assertNotRegex(listing[field], r"\$\d|\bUSD\b|19\.99|39\.99|49\.99|89\.99|40\.00")
                    self.assertIn("7", listing[field])
                    self.assertIn("lifetime", listing[field].casefold())

    def test_product_drafts_have_complete_locale_coverage_and_fit_apple_limits(self):
        draft = json.loads((DOCUMENTS / "subscription-localizations.json").read_text())
        self.assertTrue(draft["draftOnly"])
        self.assertEqual(draft["release"], VERSION)
        self.assertEqual({p["productId"] for p in draft["products"]}, PRODUCT_IDS)
        self.assertEqual(len(draft["products"]), 4)
        for product in draft["products"]:
            self.assertEqual(len(product["localizations"]), len(LOCALES))
            self.assertEqual({l["locale"] for l in product["localizations"]}, LOCALES)
            for localization in product["localizations"]:
                with self.subTest(product=product["productId"], locale=localization["locale"]):
                    self.assertGreater(len(localization["name"]), 0)
                    self.assertLessEqual(len(localization["name"]), 30)
                    self.assertGreater(len(localization["description"]), 0)
                    self.assertLessEqual(len(localization["description"]), 55)
        self.assertEqual({l["locale"] for l in draft["group"]["localizations"]}, LOCALES)
        self.assertEqual(len(draft["group"]["localizations"]), len(LOCALES))
        for localization in draft["group"]["localizations"]:
            self.assertLessEqual(len(localization["name"]), 75)

    def test_reviewer_notes_fit_and_cover_products_and_held_prices(self):
        notes = (DOCUMENTS / "reviewer-notes.txt").read_text()
        self.assertLessEqual(len(notes), 4000)
        self.assertIn(VERSION, notes)
        self.assertIn("Intended build: 51", notes)
        for product_id in PRODUCT_IDS:
            self.assertIn(product_id, notes)
        self.assertIn("50 or earlier", notes)
        self.assertIn("$19.99 Individual Lifetime", notes)
        self.assertIn("$39.99 Family Lifetime", notes)
        self.assertIn("$19.99 Family Upgrade", notes)
        self.assertNotRegex(notes, r"\$49\.99 (?:Individual|Family) Lifetime|\$89\.99")

    def test_terms_are_a_separate_unpublished_proposal(self):
        terms = (DOCUMENTS / "terms-proposed.md").read_text()
        self.assertIn("Local draft for owner and legal review", terms)
        self.assertIn("does not change the effective terms", terms)
        self.assertIn("live pricing hold", terms)
        self.assertIn("7-day free trial", terms)
        self.assertIn("Deleting the app", terms)
        self.assertIn("does not recover deleted", terms)
        self.assertIn("does not set a custom EULA", terms)
        self.assertFalse(DOCUMENTS.is_relative_to(ROOT / "marketing"))


if __name__ == "__main__":
    unittest.main()
