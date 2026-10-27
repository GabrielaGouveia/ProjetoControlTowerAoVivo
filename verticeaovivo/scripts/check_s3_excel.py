import os
import json
import urllib.request
import urllib.parse
import datetime
import hashlib
import hmac
import xml.etree.ElementTree as ET

conf = json.load(open(r'c:\Users\gabii\projetos\ProjetoControlTowerAoVivo\verticeaovivo\.databricks\bundle\dev\variable-overrides.json'))
access_key = conf['s3_access_key_id']
secret_key = conf['s3_secret_access_key']
endpoint = conf['s3_endpoint'] # e.g. https://stcpebefzlctywzpddfa.storage.supabase.co/storage/v1/s3
region = conf['aws_default_region']
bucket = 'DataLakeVertice'

# Parse endpoint URL
parsed = urllib.parse.urlparse(endpoint)
host = parsed.netloc
path_prefix = parsed.path.rstrip('/')

def sign(key, msg):
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()

def get_signature_key(key, date_stamp, region_name, service_name):
    k_date = sign(('AWS4' + key).encode('utf-8'), date_stamp)
    k_region = sign(k_date, region_name)
    k_service = sign(k_region, service_name)
    k_signing = sign(k_service, 'aws4_request')
    return k_signing

now = datetime.datetime.now(datetime.timezone.utc)
amz_date = now.strftime('%Y%m%dT%H%M%SZ')
date_stamp = now.strftime('%Y%m%d')

canonical_uri = f"{path_prefix}/{bucket}"
canonical_querystring = "list-type=2"

payload_hash = hashlib.sha256(b'').hexdigest()
canonical_headers = f'host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n'
signed_headers = 'host;x-amz-content-sha256;x-amz-date'

canonical_request = f"GET\n{canonical_uri}\n{canonical_querystring}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"

algorithm = 'AWS4-HMAC-SHA256'
credential_scope = f"{date_stamp}/{region}/s3/aws4_request"
string_to_sign = f"{algorithm}\n{amz_date}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"

signing_key = get_signature_key(secret_key, date_stamp, region, 's3')
signature = hmac.new(signing_key, string_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()

auth_header = f"{algorithm} Credential={access_key}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}"

url = f"{endpoint}/{bucket}?{canonical_querystring}"
req = urllib.request.Request(url, headers={
    'x-amz-date': amz_date,
    'x-amz-content-sha256': payload_hash,
    'Authorization': auth_header
})

try:
    with urllib.request.urlopen(req) as resp:
        xml_content = resp.read()
        root = ET.fromstring(xml_content)
        # handle xmlns
        ns = {'s3': 'http://s3.amazonaws.com/doc/2006-03-01/'}
        # Check elements
        contents = root.findall('.//{http://s3.amazonaws.com/doc/2006-03-01/}Contents')
        if not contents:
            contents = root.findall('.//Contents')
        for c in contents:
            key = c.find('{http://s3.amazonaws.com/doc/2006-03-01/}Key')
            if key is None:
                key = c.find('Key')
            size = c.find('{http://s3.amazonaws.com/doc/2006-03-01/}Size')
            if size is None:
                size = c.find('Size')
            print(key.text if key is not None else '', size.text if size is not None else '')
except Exception as e:
    print("Error:", e)
    if hasattr(e, 'read'):
        print(e.read())
