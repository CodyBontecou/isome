#!/usr/bin/env python3
"""Capture real iPad features for scripts/compose_ipad_field_notes.py.

Use a dedicated screenshot simulator: this reinstalls the app and seeds synthetic data.
"""
import argparse,pathlib
import capture_localized_screenshots as capture

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--device',required=True,help='Dedicated iPad simulator UDID')
    p.add_argument('--app',type=pathlib.Path,required=True,help='Built simulator .app')
    p.add_argument('--locales',default='en-US,ar-SA,es-ES,fr-FR,hi,ja,pt-BR,ru,zh-Hans')
    a=p.parse_args();assert a.app.is_dir(),a.app
    capture.boot(a.device);capture.status_bar(a.device,ipad=True);capture.reinstall(a.device,capture.BUNDLE_ID,a.app)
    for locale in a.locales.split(','):
        language,apple_locale=capture.LOCALES[locale];capture.warm_up_iphone(a.device,language,apple_locale)
        for name,arguments,wait in capture.IPHONE_STORY:
            destination=capture.ROOT/'screenshots/whereday/ipad-v2/raw'/locale/(name+'.png')
            capture.launch_and_capture(a.device,capture.BUNDLE_ID,language,apple_locale,arguments,destination,wait,minimum_entropy=3.0)
        print('Captured iPad',locale,flush=True)
if __name__=='__main__':main()
