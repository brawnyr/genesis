import os
from god.samples import SpliceBrowser


def test_splice_browser_finds_directory():
    browser = SpliceBrowser()
    assert os.path.isdir(browser.root_path)


def test_splice_browser_list_packs():
    browser = SpliceBrowser()
    packs = browser.list_packs()
    assert isinstance(packs, list)
    assert len(packs) > 0


def test_splice_browser_list_samples_in_pack():
    browser = SpliceBrowser()
    packs = browser.list_packs()
    if packs:
        samples = browser.list_samples(packs[0])
        assert isinstance(samples, list)
