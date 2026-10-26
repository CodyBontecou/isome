"""Keep the guide hub's structured article list aligned with published pages."""
from html.parser import HTMLParser
import json
import re
from urllib.parse import urljoin, urlsplit

BASE = 'https://whereday.com'
SCHEMA = re.compile(r'(<script type="application/ld\+json">)(.*?)(</script>)', re.S)


class Document(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.links = set()
        self.nodes = []
        self.feed(source)
        for match in SCHEMA.finditer(source):
            data = json.loads(match[2])
            self.nodes.extend(data.get('@graph', [data]))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and attrs.get('href'):
            target = urlsplit(urljoin(BASE + '/blog/', attrs['href']))
            self.links.add(target._replace(fragment='', query='').geturl())


def inventory(public):
    source = (public / 'blog/index.html').read_text()
    hub = Document(source)
    blogs = [node for node in hub.nodes if node.get('@type') == 'Blog']
    if len(blogs) != 1:
        raise ValueError('guide hub must contain exactly one Blog node')
    references = []
    for path in sorted((public / 'blog').glob('*/index.html')):
        url = BASE + '/' + path.relative_to(public).as_posix().removesuffix('index.html')
        articles = [node for node in Document(path.read_text()).nodes
                    if node.get('@type') == 'BlogPosting']
        if len(articles) != 1 or not articles[0].get('@id'):
            raise ValueError(f'published guide needs one identified BlogPosting: {url}')
        if url not in hub.links:
            raise ValueError(f'published guide missing a reader link from hub: {url}')
        references.append({'@id': articles[0]['@id']})
    return source, blogs[0], references


def sync(public):
    source, blog, references = inventory(public)
    blog['blogPost'] = references
    def replace(match):
        data = json.loads(match[2])
        if not any(node.get('@type') == 'Blog' for node in data.get('@graph', [data])):
            return match[0]
        for node in data.get('@graph', [data]):
            if node.get('@type') == 'Blog':
                node['blogPost'] = references
        return match[1] + '\n' + json.dumps(data, ensure_ascii=False, indent=2) + '\n  ' + match[3]
    (public / 'blog/index.html').write_text(SCHEMA.sub(replace, source))


def check(public):
    _, blog, references = inventory(public)
    if blog.get('blogPost') != references:
        raise ValueError('guide hub structured article list differs from published guides; rebuild the site')
