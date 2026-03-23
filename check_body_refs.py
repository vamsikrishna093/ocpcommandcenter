import json
import re

with open('N8N/n8n_master_orchestrator.json') as f:
    wf = json.load(f)

# Find nodes where $json.body appears as a VALUE (not as a property accessor $json.body.xxx)
# These are cases where the original $json.body meant "the body text field" which is now at $json.body.body
for n in wf['nodes']:
    if 'jsonBody' in n.get('parameters', {}):
        jb = n['parameters']['jsonBody']
        # Find $json.body that is NOT followed by a dot (i.e., bare $json.body used as a value)
        matches = list(re.finditer(r'\$json\.body(?!\.)', jb))
        if matches:
            print(f"{n['name']}:")
            for m in matches:
                ctx = jb[max(0,m.start()-15):m.end()+15]
                print(f"  ...{ctx}...")
    
    if 'jsCode' in n.get('parameters', {}):
        js = n['parameters']['jsCode']
        matches = list(re.finditer(r'\$json\.body(?!\.)', js))
        if matches:
            print(f"{n['name']} (jsCode):")
            for m in matches:
                ctx = js[max(0,m.start()-15):m.end()+15]
                print(f"  ...{ctx}...")
