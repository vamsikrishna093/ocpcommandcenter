import json
import re

with open('N8N/n8n_master_orchestrator.json', 'r') as f:
    wf = json.load(f)

fixes = 0
for node in wf['nodes']:
    # Fix jsonBody expressions in HTTP Request nodes
    if 'jsonBody' in node.get('parameters', {}):
        old = node['parameters']['jsonBody']
        new = re.sub(r'\$json\.(?!body\b)', '$json.body.', old)
        if new != old:
            node['parameters']['jsonBody'] = new
            print(f"  Fixed jsonBody in: {node['name']}")
            fixes += 1

    # Fix jsCode expressions in Code nodes
    if 'jsCode' in node.get('parameters', {}):
        old = node['parameters']['jsCode']
        new = old
        # Fix $('Webhook: ...').first().json.XXX -> $('Webhook: ...').first().json.body.XXX
        new = re.sub(
            r"(\$\('Webhook: [^']+'\)\.first\(\)\.json)\.(?!body\b)",
            r"\1.body.",
            new
        )
        # Fix payload.XXX in Notification Hub (where payload = $input.first().json from webhook)
        if node['name'] == 'Notification Hub':
            new = re.sub(r'payload\.(?!body\b)(?=\w)', 'payload.body.', new)

        if new != old:
            node['parameters']['jsCode'] = new
            print(f"  Fixed jsCode in: {node['name']}")
            fixes += 1

with open('N8N/n8n_master_orchestrator.json', 'w') as f:
    json.dump(wf, f, indent=2, ensure_ascii=False)

print(f"\nDone - {fixes} nodes fixed")
