"""Regression checks for guide hub discovery and structured inventory drift."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from blog_inventory import BASE, Document, check, sync


def schema(node):
    return '<script type="application/ld+json">' + json.dumps(node) + '</script>'


class BlogInventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.public = Path(self.temp.name)
        (self.public / 'blog').mkdir()
        self.hub = self.public / 'blog/index.html'
        self.hub.write_text(schema({'@graph': [{'@type': 'Blog', 'blogPost': []}]}))

    def article(self, slug, fragment=''):
        path = self.public / 'blog' / slug / 'index.html'
        path.parent.mkdir()
        url = BASE + '/blog/' + slug + '/'
        path.write_text(schema({'@type': 'BlogPosting', '@id': url + fragment}))
        return url

    def link(self, url):
        self.hub.write_text(self.hub.read_text() + '<a href="' + url + '">Guide</a>')

    def test_new_published_guide_is_added_using_its_actual_identity(self):
        first = self.article('journal', '#article')
        self.link(first)
        sync(self.public)
        new = self.article('country-days')
        self.link(new)
        sync(self.public)
        check(self.public)
        blog = Document(self.hub.read_text()).nodes[0]
        self.assertEqual(blog['blogPost'], [{'@id': new}, {'@id': first + '#article'}])
        before = self.hub.read_bytes()
        sync(self.public)
        self.assertEqual(before, self.hub.read_bytes())

    def test_check_rejects_stale_list_and_unlinked_article(self):
        url = self.article('country-days')
        with self.assertRaisesRegex(ValueError, 'missing a reader link'):
            sync(self.public)
        self.link(url)
        with self.assertRaisesRegex(ValueError, 'differs from published'):
            check(self.public)

    def test_nonpublic_draft_and_integration_do_not_become_blog_entries(self):
        draft = self.public.parent / (self.public.name + '-draft.html')
        self.addCleanup(lambda: draft.unlink(missing_ok=True))
        draft.write_text(schema({'@type': 'BlogPosting', '@id': BASE + '/blog/unreleased/'}))
        integration = self.public / 'integrations/example/index.html'
        integration.parent.mkdir(parents=True)
        integration.write_text(schema({'@type': 'BlogPosting', '@id': BASE + '/integrations/example/'}))
        sync(self.public)
        check(self.public)
        self.assertEqual(Document(self.hub.read_text()).nodes[0]['blogPost'], [])


if __name__ == '__main__':
    unittest.main()
