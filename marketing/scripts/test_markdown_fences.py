"""Keep displayed nested Markdown code blocks intact in negotiated output."""
import unittest
from build_agentic import Markdown


class MarkdownFenceTests(unittest.TestCase):
    def render(self, content):
        converter = Markdown('https://isome.isolated.tech/example/')
        converter.feed('<main><pre><code>' + content + '</code></pre><p>After example.</p></main>')
        return converter.result()

    def test_ordinary_code_keeps_existing_fence(self):
        self.assertIn('```\nsource: example.md\n```', self.render('source: example.md'))

    def test_nested_fence_remains_literal_inside_longer_outer_fence(self):
        example = '```iso-me\nsource: Location/example.md\n```'
        result = self.render(example)
        self.assertIn('````\n' + example + '\n````\n\nAfter example.', result)

    def test_longer_runs_are_also_protected(self):
        self.assertIn('`````\n````demo\n````\n`````', self.render('````demo\n````'))


if __name__ == '__main__':
    unittest.main()
