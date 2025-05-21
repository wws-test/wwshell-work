# test_simple.py
import docx
from docx.document import Document as DocxDocClass

print(f"--- Simple Test (Poetry Env) ---")
print(f"docx module location: {docx.__file__}")
print(f"DocxDocClass location: {DocxDocClass.__module__}.{DocxDocClass.__name__}")
print(f"docx.Document location: {docx.document.Document.__module__}.{docx.document.Document.__name__}")

print(f"docx version: {docx.__version__}")
print(f"Is DocxDocClass the same as docx.Document?: {DocxDocClass is docx.Document}")
print(f"iter_block_items in Document class (DocxDocClass): {'iter_block_items' in dir(DocxDocClass)}")
print(f"iter_block_items in Document class (docx.Document): {'iter_block_items' in dir(docx.Document)}")

try:
    doc = docx.Document()
    print(f"iter_block_items in new doc instance: {'iter_block_items' in dir(doc)}")
except Exception as e:
    print(f"Error creating/inspecting Document instance: {e}")