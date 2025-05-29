# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['h3c_doc_checker\\__main__.py'],
    pathex=[],
    binaries=[],
    datas=[('C:\\Users\\admin\\Documents\\GitHub\\wwshell-work\\H3C\\check\\h3c_doc_checker\\resources', 'h3c_doc_checker/resources'), ('C:\\Users\\admin\\Documents\\GitHub\\wwshell-work\\H3C\\check\\dist\\config', 'h3c_doc_checker/config')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='docx_checker',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['C:\\Users\\admin\\Documents\\GitHub\\wwshell-work\\H3C\\check\\h3c_doc_checker\\resources\\icon.ico'],
)
