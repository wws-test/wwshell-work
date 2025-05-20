from PIL import Image, ImageDraw
from pathlib import Path

def create_default_icon():
    # 创建一个 256x256 的图像，带透明通道
    img = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 绘制一个简单的文档图标
    # 文档底色
    draw.rectangle((48, 32, 208, 224), fill=(255, 255, 255), outline=(0, 120, 212), width=8)
    # 文档折角
    draw.polygon([(168, 32), (208, 72), (168, 72)], fill=(0, 120, 212))
    # 横线装饰
    for y in range(96, 192, 32):
        draw.line((72, y, 184, y), fill=(0, 120, 212), width=8)
    
    # 确保目标目录存在
    resources_dir = Path('h3c_doc_checker/resources')
    resources_dir.mkdir(parents=True, exist_ok=True)
    
    # 保存为 PNG 格式，因为 PIL 的 ICO 支持有限
    png_path = resources_dir / 'icon.png'
    img.save(png_path, format='PNG')
    
    # 转换为 ICO 格式
    img_resized = img.resize((128, 128), Image.Resampling.LANCZOS)
    ico_path = resources_dir / 'icon.ico'
    img_resized.save(ico_path, format='ICO')

if __name__ == '__main__':
    import os
    if not os.path.exists('resources'):
        os.makedirs('resources')
    create_default_icon()
