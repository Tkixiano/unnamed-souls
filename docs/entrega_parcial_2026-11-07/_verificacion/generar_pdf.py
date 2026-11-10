from pathlib import Path
import re, html
from reportlab.pdfgen import canvas
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, PageBreak, Table, TableStyle, Image, KeepTogether, Flowable)
from reportlab.platypus.tableofcontents import TableOfContents
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from PIL import Image as PILImage

OUT=Path(__file__).resolve().parents[1]
pdfmetrics.registerFont(TTFont('Arial','C:/Windows/Fonts/arial.ttf'))
pdfmetrics.registerFont(TTFont('Arial-Bold','C:/Windows/Fonts/arialbd.ttf'))
pdfmetrics.registerFont(TTFont('Arial-Italic','C:/Windows/Fonts/ariali.ttf'))
pdfmetrics.registerFontFamily('Arial',normal='Arial',bold='Arial-Bold',italic='Arial-Italic',boldItalic='Arial-Bold')
NAVY=colors.HexColor('#163148'); GOLD=colors.HexColor('#ae7a29'); GREY=colors.HexColor('#53616c')
styles={
 'body':ParagraphStyle('body',fontName='Arial',fontSize=10.4,leading=15,spaceAfter=8,textColor=colors.HexColor('#202a32')),
 'h1':ParagraphStyle('h1',fontName='Arial-Bold',fontSize=17,leading=21,spaceBefore=12,spaceAfter=12,textColor=NAVY,keepWithNext=True),
 'h2':ParagraphStyle('h2',fontName='Arial-Bold',fontSize=12,leading=16,spaceBefore=12,spaceAfter=7,textColor=NAVY,keepWithNext=True),
 'caption':ParagraphStyle('caption',fontName='Arial-Italic',fontSize=9,leading=12,spaceBefore=6,spaceAfter=12,textColor=GREY),
 'cell':ParagraphStyle('cell',fontName='Arial',fontSize=8.8,leading=12),
 'cellhead':ParagraphStyle('cellhead',fontName='Arial-Bold',fontSize=8.8,leading=12,textColor=colors.white),
 'bullet':ParagraphStyle('bullet',fontName='Arial',fontSize=10.4,leading=15,leftIndent=12,firstLineIndent=-9,spaceAfter=5),
 'ref':ParagraphStyle('ref',fontName='Arial',fontSize=9.1,leading=13,spaceAfter=7,wordWrap='CJK'),
}

def inline(s):
 s=html.escape(s)
 s=re.sub(r'\*\*(.+?)\*\*',r'<b>\1</b>',s)
 s=re.sub(r'`(.+?)`',r'<font color="#345b73">\1</font>',s)
 s=re.sub(r'(https://[^\s<]+)',lambda m:'<link href="'+m.group(1)+'" color="#345b73">'+m.group(1)+'</link>',s)
 return s

class Doc(BaseDocTemplate):
 def afterFlowable(self, flowable):
  if isinstance(flowable,Paragraph) and getattr(flowable,'_toc',False):
   key='sec-'+str(self.seq.nextf('heading'))
   self.canv.bookmarkPage(key)
   self.canv.addOutlineEntry(flowable.getPlainText(),key,0,False)
   self.notify('TOCEntry',(0,flowable.getPlainText(),self.page,key))

def page(c,doc):
 w,h=A4;c.saveState()
 if doc.page==1:
  c.setFillColor(NAVY);c.rect(0,h-14,w,14,fill=1,stroke=0)
  c.setFont('Arial-Bold',13);c.drawString(52,h-64,'ESCUELA TÉCNICA N.º 3 DE BENAVÍDEZ')
  c.setFont('Arial',11);c.setFillColor(GREY);c.drawString(52,h-86,'Especialidad Informática | Ciclo lectivo 2026')
  c.setFillColor(GOLD);c.rect(52,h-146,60,4,fill=1,stroke=0)
  c.setFillColor(NAVY);c.setFont('Arial-Bold',31)
  for i,line in enumerate(['Desarrollo de un','videojuego','Soulslike 3D']): c.drawString(52,h-205-i*40,line)
  c.setFont('Arial',18);c.drawString(52,h-345,'Informe parcial de desarrollo')
  c.setFillColor(GREY);c.setFont('Arial',11)
  c.drawString(52,h-380,'Fecha: 7 de noviembre de 2026')
  c.drawString(52,h-399,'Exposición prevista: 17 de noviembre de 2026')
  c.drawString(52,h-426,'Corte: fases 1A-1D, 2A-2E y 3A-3C. Fase 4A no iniciada.')
  y=h-476
  for name,label,height in [('proyecto','Nombre definitivo del proyecto',24),('integrantes','Integrantes',42),('curso','Curso y división',24),('docentes','Docente/s',24)]:
   c.setFont('Arial',10);c.drawString(52,y,label)
   c.acroForm.textfield(name=name,tooltip=label,x=52,y=y-height-8,width=w-104,height=height,fontName='Helvetica',fontSize=10,borderStyle='underlined',borderWidth=0.7,borderColor=colors.HexColor('#94a4ae'),fillColor=colors.HexColor('#f3f6f8'),textColor=NAVY,forceBorder=True,fieldFlags='multiline' if name=='integrantes' else '',value='')
   y-=height+36
  c.setFont('Arial-Italic',9);c.drawString(52,40,'Campos de identificación editables. Documento parcial, con evidencia y límites de validación.')
 else:
  c.setStrokeColor(colors.HexColor('#d5dfe5'));c.line(50,h-37,w-50,h-37)
  c.setFillColor(GREY);c.setFont('Arial',8.5);c.drawString(50,h-28,'INFORME PARCIAL | SOULSLIKE 3D')
  c.drawRightString(w-50,h-28,'Informática - 2026')
  c.line(50,39,w-50,39)
  c.drawString(50,25,'Corte: 07/11/2026 | Fase 4A no iniciada')
  c.drawRightString(w-50,25,f'Página {doc.page}')
 c.restoreState()

target=OUT/'INFORME_PARCIAL.pdf'
doc=Doc(str(target),pagesize=A4,leftMargin=50,rightMargin=50,topMargin=53,bottomMargin=52,title='Desarrollo de un videojuego Soulslike 3D - Informe parcial',author='Equipo del proyecto - completar identificación',pageCompression=1)
doc.addPageTemplates(PageTemplate(id='normal',frames=[Frame(50,52,A4[0]-100,A4[1]-105,id='body',leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0)],onPage=page))
story=[Spacer(1,1),PageBreak(),Paragraph('Índice',styles['h1'])]
toc=TableOfContents()
toc.levelStyles=[ParagraphStyle('toc',fontName='Arial',fontSize=11,leading=17,spaceBefore=8,textColor=NAVY)]
story += [toc,Spacer(1,25),Paragraph('Alcance: prototipo y evidencia hasta 3C. Los detalles de APIs y archivos se entregan en el anexo editable. Los números de prueba corresponden a informes históricos contrastados.',styles['body']),PageBreak()]

text=(OUT/'INFORME_PARCIAL.md').read_text(encoding='utf-8')
text=text[text.index('## 1. Introducción'):]
lines=text.splitlines();i=0
while i<len(lines):
 line=lines[i].strip()
 if not line: i+=1;continue
 if line=='<!-- pagebreak -->':
  if not isinstance(story[-1],PageBreak):story.append(PageBreak())
  i+=1;continue
 if line.startswith('## '):
  p=Paragraph(inline(line[3:]),styles['h1']);p._toc=True;story.append(p);i+=1;continue
 if line.startswith('### '):story.append(Paragraph(inline(line[4:]),styles['h2']));i+=1;continue
 if line.startswith('|'):
  rows=[]
  while i<len(lines) and lines[i].strip().startswith('|'):
   cells=[s.strip() for s in lines[i].strip().strip('|').split('|')]
   if not all(re.fullmatch(r':?-+:?',x.replace(' ','')) for x in cells):rows.append(cells)
   i+=1
  n=len(rows[0]);width=doc.width
  ratios={2:[.31,.69],3:[.20,.27,.53],6:[.27,.146,.146,.146,.146,.146]}.get(n,[1/n]*n)
  if 'Fase'==rows[0][0]:ratios=[.13,.31,.56]
  if 'Perfil'==rows[0][0] and n==6:ratios=[.14,.23,.12,.15,.13,.23]
  if n==6 and ('Ataque' in rows[0][0] or 'Patrón' in rows[0][0]):ratios=[.32,.136,.136,.136,.136,.136]
  if 'Parámetro'==rows[0][0]:ratios=[.5,.5]
  rs=sum(ratios);widths=[width*x/rs for x in ratios]
  data=[[Paragraph(inline(c),styles['cellhead' if j==0 else 'cell']) for c in row] for j,row in enumerate(rows)]
  table=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
  table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),NAVY),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.HexColor('#f0f4f7'),colors.white]),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),('LINEBELOW',(0,-1),(-1,-1),.4,colors.HexColor('#b8c9d4'))]))
  story += [table,Spacer(1,12)];continue
 if line.startswith('!['):
  match=re.match(r'!\[(.*?)\]\((.*?)\)',line);path=OUT/match.group(2)
  im=PILImage.open(path);w=min(460,doc.width);h=w*im.height/im.width
  flow=Image(str(path),width=w,height=h);flow.hAlign='CENTER';items=[flow]
  i+=1
  while i<len(lines) and not lines[i].strip():i+=1
  if i<len(lines) and lines[i].startswith('Figura '):
   items.append(Paragraph(inline(lines[i]),styles['caption']));i+=1
  story.append(KeepTogether(items));continue
 if line.startswith('- '):
  story.append(Paragraph('• '+inline(line[2:]),styles['bullet']));i+=1;continue
 para=[line];i+=1
 while i<len(lines) and lines[i].strip() and not lines[i].startswith(('#','|','![','- ','<!--')):
  para.append(lines[i].strip());i+=1
 value=' '.join(para)
 story.append(Paragraph(inline(value),styles['ref' if value.startswith(('[R','[P')) else 'body']))

doc.multiBuild(story)
print('Generated',target)
