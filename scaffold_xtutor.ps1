$ErrorActionPreference = "Stop"
$PROJECT="xtutor"
New-Item -ItemType Directory -Force -Path "$PROJECT/app","$PROJECT/public" | Out-Null

@'
APP_HOST=127.0.0.1
APP_PORT=5000
APP_DEBUG=false
APP_CSP=default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; base-uri 'self'; form-action 'self'
MAX_UPLOAD_MB=5
MAX_INPUT_CHARS=3000
RAP_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXX
RAP_API_URL=https://portal.genai.nchc.org.tw/api/v1/chat/completions
RAP_MODEL=gemma-3-taide-12b_alpha_v1.0
RAP_MAX_TOKENS=5000
RAP_TEMPERATURE=0.2
RAP_TIMEOUT_S=120
RAP_RETRY=3
'@ | Set-Content "$PROJECT/.env.example" -Encoding UTF8

@'
fastapi>=0.114.0
uvicorn[standard]>=0.30.0
python-dotenv>=1.0.1
pydantic>=2.8.0
pypdf==4.2.0
httpx>=0.27.0
'@ | Set-Content "$PROJECT/requirements.txt" -Encoding UTF8

@'
$ErrorActionPreference = "Stop"
if (Test-Path ".env") {
  Get-Content .env | ForEach-Object {
    if ($_ -and -not $_.StartsWith("#")) {
      $name, $value = $_.Split("=", 2)
      [System.Environment]::SetEnvironmentVariable($name, $value)
    }
  }
}
python -m venv .venv
. .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.server:app --host $env:APP_HOST --port $env:APP_PORT
'@ | Set-Content "$PROJECT/run.ps1" -Encoding UTF8

@'
import os
from pydantic import BaseModel, Field
from dotenv import load_dotenv
load_dotenv()
class Settings(BaseModel):
    app_host: str = Field(default=os.getenv("APP_HOST", "127.0.0.1"))
    app_port: int = Field(default=int(os.getenv("APP_PORT", "5000")))
    app_debug: bool = Field(default=os.getenv("APP_DEBUG", "false").lower() == "true")
    csp: str = Field(default=os.getenv("APP_CSP", "default-src 'self'; connect-src 'self'"))
    max_upload_mb: int = Field(default=int(os.getenv("MAX_UPLOAD_MB", "5")))
    max_input_chars: int = Field(default=int(os.getenv("MAX_INPUT_CHARS", "3000")))
    rap_api_key: str = Field(default=os.getenv("RAP_API_KEY", ""))
    rap_api_url: str = Field(default=os.getenv("RAP_API_URL", ""))
    rap_model: str = Field(default=os.getenv("RAP_MODEL", "gemma-3-taide-12b_alpha_v1.0"))
    rap_max_tokens: int = Field(default=int(os.getenv("RAP_MAX_TOKENS", "5000")))
    rap_temperature: float = Field(default=float(os.getenv("RAP_TEMPERATURE", "0.2")))
    rap_timeout_s: int = Field(default=int(os.getenv("RAP_TIMEOUT_S", "120")))
    rap_retry: int = Field(default=int(os.getenv("RAP_RETRY", "3")))
settings = Settings()
'@ | Set-Content "$PROJECT/app/settings.py" -Encoding UTF8

@'
import re
from io import BytesIO
from typing import Optional, List
from pypdf import PdfReader
def extract_pdf_text(pdf_bytes: bytes, max_pages: Optional[int] = None) -> str:
    reader = PdfReader(BytesIO(pdf_bytes))
    n_pages = len(reader.pages)
    if max_pages is not None:
        n_pages = min(n_pages, max_pages)
    texts: List[str] = []
    for i in range(n_pages):
        try:
            txt = reader.pages[i].extract_text() or ""
        except Exception:
            txt = ""
        txt = re.sub(r"[ \t]+\n", "\n", txt)
        txt = re.sub(r"\n{3,}", "\n\n", txt)
        texts.append(txt)
    text = "\n".join(texts).strip()
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()
'@ | Set-Content "$PROJECT/app/utils_pdf.py" -Encoding UTF8

@'
# （同 bash 版本 app/server.py 內容，略）
# 為節省訊息長度，建議你從上一則訊息複製 server.py 內容到此檔案：
# xtutor/app/server.py
'@ | Set-Content "$PROJECT/app/server.py" -Encoding UTF8

@'
<!DOCTYPE html>
<html lang="zh-Hant"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Xtutor - AI Mentor</title><link rel="stylesheet" href="/static/tailwind.css" /><link rel="stylesheet" href="/static/index.css" />
<style>@keyframes fadeIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}.animate-fadeIn{animation:fadeIn .5s ease-in-out}</style></head>
<body><div id="root"><div id="app-container" class="min-h-screen transition-all duration-500"><div class="max-w-4xl mx-auto p-6">
<h1 class="text-3xl font-bold mb-6">Xtutor - Demo</h1><input id="file-upload" type="file" accept=".pdf" /><button id="review-button" disabled>開始審查</button><pre id="out"></pre>
</div></div></div>
<script>
document.addEventListener('DOMContentLoaded',()=>{const API_URL='/api/review';const up=document.getElementById('file-upload');const btn=document.getElementById('review-button');const out=document.getElementById('out');let file=null;
const escapeHtml=(s)=>String(s).replace(/[&<>\"']/g,(c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));up.addEventListener('change',e=>{file=e.target.files[0]||null;btn.disabled=!file;});
btn.addEventListener('click',async()=>{if(!file){return}btn.disabled=true;out.textContent='上傳分析中…';const fd=new FormData();fd.append('file',file);const controller=new AbortController();const t=setTimeout(()=>controller.abort(),30000);
try{const r=await fetch(API_URL,{method:'POST',body:fd,signal:controller.signal});clearTimeout(t);if(!r.ok){const err=await r.json().catch(()=>({detail:`HTTP ${r.status}`}));throw new Error(err.detail)}const data=await r.json();out.textContent=JSON.stringify(data,null,2);}
catch(e){out.textContent='錯誤：'+(e&&e.message?e.message:String(e));}finally{btn.disabled=false;}});});
</script></body></html>
'@ | Set-Content "$PROJECT/public/index.html" -Encoding UTF8

@'
body { font-family: system-ui, -apple-system, "Noto Sans TC", sans-serif; }
'@ | Set-Content "$PROJECT/public/index.css" -Encoding UTF8

@'
/* 放已編譯好的 Tailwind CSS；若尚未編譯，可先用 CDN 開發，正式佈署請改為本地檔。 */
'@ | Set-Content "$PROJECT/public/tailwind.css" -Encoding UTF8

Write-Host "✅ 專案已建立在 .\$PROJECT\"
Write-Host "接下來："
Write-Host "1) cd $PROJECT"
Write-Host "2) Copy-Item .env.example .env   # 編輯 .env，填入 RAP_API_KEY"
Write-Host "3) .\\run.ps1"
Write-Host "4) 瀏覽 http://127.0.0.1:5000"
