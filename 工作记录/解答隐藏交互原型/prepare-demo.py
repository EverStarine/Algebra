from pathlib import Path
import copy
import json
import shutil
import subprocess
from pypdf import PdfReader, PdfWriter
from pypdf.generic import NameObject, DictionaryObject, ArrayObject, NumberObject, DecodedStreamObject, BooleanObject
from PIL import Image, ImageDraw

folder=Path(__file__).resolve().parent
raw=folder/'answer-toggle-demo.pdf'
final=folder/'解答隐藏样例.pdf'
reader=PdfReader(raw)
writer=PdfWriter()
writer.clone_document_from_reader(reader)
layers={str(ref.get_object()['/Name']):ref for ref in writer._root_object['/OCProperties']['/OCGs']}
widgets=[]
for page in writer.pages:
 for ref in page.get('/Annots',[]):
  annot=ref.get_object()
  if str(annot.get('/T','')).startswith('ocgx2@'):
   gate=annot['/OC']['/VE'][1]
   annot[NameObject('/OC')]=gate  # 单一可见性门控无需较新的布尔可见性表达式。
   annot[NameObject('/H')]=NameObject('/N')
   annot[NameObject('/Border')]=ArrayObject([NumberObject(0)]*3)
   rect=annot['/Rect'];w=float(rect[2]-rect[0]);h=float(rect[3]-rect[1])
   blank=DecodedStreamObject();blank.set_data(b'')
   blank.update({NameObject('/Type'):NameObject('/XObject'),NameObject('/Subtype'):NameObject('/Form'),NameObject('/BBox'):ArrayObject([NumberObject(0),NumberObject(0),NumberObject(round(w)),NumberObject(round(h))]),NameObject('/Resources'):DictionaryObject()})
   annot[NameObject('/AP')]=DictionaryObject({NameObject('/N'):writer._add_object(blank)})
   widgets.append(annot)
writer._root_object['/AcroForm'][NameObject('/NeedAppearances')]=BooleanObject(False)
with final.open('wb') as stream:writer.write(stream)

# 从真实事件字典核对交互状态，不把人工设置的图层状态冒充阅读器实测。
r=PdfReader(final);props=r.trailer['/Root']['/OCProperties'];refs=list(props['/OCGs'])
names={ref.idnum:str(ref.get_object()['/Name']) for ref in refs}
state={name:True for name in names.values()}
for ref in props['/D'].get('/OFF',[]):state[names[ref.idnum]]=False
annots=[a.get_object() for a in r.pages[0].get('/Annots',[])]
buttons=[a for a in annots if str(a.get('/T','')).startswith('ocgx2@')]
links=[a for a in annots if a.get('/Subtype')=='/Link']
assert len(buttons)==2 and len(links)==2
initial=dict(state)
def apply(action):
 assert action['/S']=='/SetOCGState'
 mode=None
 for item in action['/State']:
  if isinstance(item,str):mode=str(item)
  else:
   name=names[item.idnum]
   state[name]={'/ON':True,'/OFF':False,'/Toggle':not state[name]}[mode]
def check(one_answer,one_hint,one_button):
 assert state['one solution']==one_answer
 assert (state['one hidden'] and state['one hover'])==one_hint
 assert state[str(buttons[0]['/OC']['/Name'])]==one_button
check(False,False,True)
apply(buttons[0]['/AA']['/E']);check(False,True,True)
hover=dict(state)
apply(buttons[0]['/AA']['/X']);check(False,False,True)
apply(buttons[0]['/AA']['/E']);apply(buttons[0]['/A']);check(True,False,False)
assert not state['two solution']
apply(buttons[0]['/AA']['/E']);check(True,False,False)
apply(links[0]['/A']);assert state==initial
apply(links[1]['/A']);check(True,False,False);assert state['two solution']
revealed=dict(state)

qa=folder/'qa';qa.mkdir(exist_ok=True)
def variant(label,states):
 w=PdfWriter();w.clone_document_from_reader(PdfReader(final))
 props=w._root_object['/OCProperties'];cfg=props['/D'];cfg[NameObject('/ON')]=ArrayObject();cfg[NameObject('/OFF')]=ArrayObject()
 for ref in props['/OCGs']:
  obj=ref.get_object();on=states[str(obj['/Name'])]
  cfg['/ON' if on else '/OFF'].append(ref)
  obj.setdefault(NameObject('/Usage'),DictionaryObject())[NameObject('/View')]=DictionaryObject({NameObject('/ViewState'):NameObject('/ON' if on else '/OFF')})
 path=qa/f'{label}.pdf'
 with path.open('wb') as stream:w.write(stream)
 subprocess.run(['pdftoppm','-f','1','-l','1','-singlefile','-scale-to','1450','-png',str(path),str(qa/label)],check=True,capture_output=True)
 return Image.open(qa/f'{label}.png').convert('RGB')
ims=[variant('hidden',initial),variant('hover',hover),variant('revealed',revealed)]
# 只比较第一道题区域的三种状态，避免无关批量渲染。
rect=buttons[0]['/Rect'];pw=float(r.pages[0].mediabox.width);ph=float(r.pages[0].mediabox.height)
sx=ims[0].width/pw;sy=ims[0].height/ph
crop=(int((float(rect[0])-10)*sx),int((ph-float(rect[3])-34)*sy),int((float(rect[2])+10)*sx),int((ph-float(rect[1])+10)*sy))
crops=[im.crop(crop) for im in ims]
canvas=Image.new('RGB',(sum(im.width for im in crops),max(im.height for im in crops)+25),'white')
x=0
for label,im in zip(['Hidden','Hover','Revealed'],crops):
 canvas.paste(im,(x,25));ImageDraw.Draw(canvas).text((x+8,5),label,fill='black');x+=im.width
canvas.save(qa/'states.png')

report={'pages':len(r.pages),'layers':list(names.values()),'answer_regions':2,'event_checks':'passed: blank, hover, exit, reveal, no repeated hint, independent answers, reset, reveal all','native_reader_interaction_tested':False,'pdf':str(final)}
(qa/'checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
