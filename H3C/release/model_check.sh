#!/bin/bash

#############################################################################
# 脚本名称: model_table_report_fixed.sh
# 描述: 生成简洁的表格形式大模型文档统计报告（修复乱码版本）
#
# 作者: Claude
# 创建日期: 2024-12-19
# 版本: 1.1
#############################################################################

# 检测是否支持颜色输出
USE_COLOR=true

# 检查终端是否支持颜色
if [ ! -t 1 ] || [ "$TERM" = "dumb" ] || [ -n "$NO_COLOR" ]; then
    USE_COLOR=false
fi

# 检查是否有--no-color参数
for arg in "$@"; do
    if [ "$arg" = "--no-color" ] || [ "$arg" = "--plain" ]; then
        USE_COLOR=false
        break
    fi
done

# 定义颜色函数
if [ "$USE_COLOR" = true ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    RED=''
    YELLOW=''
    CYAN=''
    BOLD=''
    NC=''
fi

# 颜色输出函数
print_colored() {
    local color="$1"
    local text="$2"
    if [ "$USE_COLOR" = true ]; then
        echo -e "${color}${text}${NC}"
    else
        echo "$text"
    fi
}

# 基础路径
BASE_PATH="/HDD_Raid/SVN_MODEL_REPO/Vendor"

# 定义要检查的厂商
VENDORS=("Cambricon" "Enflame" "Iluvatar" "Kunlunxin" "MetaX" "Moffett")

print_colored "$CYAN" "正在统计大模型文档，请稍候..."

# 统计变量
declare -A vendor_models
declare -A vendor_complete
declare -A vendor_incomplete
declare -A vendor_versions
declare -A vendor_docs
declare -A vendor_words
declare -A vendor_pdfs
declare -A vendor_missing_models

# 初始化
for vendor in "${VENDORS[@]}"; do
    vendor_models[$vendor]=0
    vendor_complete[$vendor]=0
    vendor_incomplete[$vendor]=0
    vendor_versions[$vendor]=0
    vendor_docs[$vendor]=0
    vendor_words[$vendor]=0
    vendor_pdfs[$vendor]=0
    vendor_missing_models[$vendor]=""
done

# 总计变量
total_models=0
total_complete=0
total_incomplete=0
total_versions=0
total_docs=0
total_words=0
total_pdfs=0

# 检查每个厂商
for vendor in "${VENDORS[@]}"; do
    vendor_path="$BASE_PATH/$vendor"
    
    # 检查厂商目录是否存在
    if [ ! -d "$vendor_path" ]; then
        continue
    fi
    
    # 获取GPU型号目录
    gpu_dirs=$(find "$vendor_path" -mindepth 1 -maxdepth 1 -type d -not -path "*.svn*" 2>/dev/null)
    
    # 遍历GPU型号目录
    while IFS= read -r gpu_dir; do
        if [ -z "$gpu_dir" ] || [ ! -d "$gpu_dir" ] || [[ "$gpu_dir" == *"/.svn"* ]]; then
            continue
        fi
        
        # 获取大模型目录
        model_dirs=$(find "$gpu_dir" -mindepth 1 -maxdepth 1 -type d -not -path "*.svn*" 2>/dev/null)
        
        # 遍历大模型目录
        while IFS= read -r model_dir; do
            if [ -z "$model_dir" ] || [ ! -d "$model_dir" ] || [[ "$model_dir" == *"/.svn"* ]]; then
                continue
            fi
            
            model_name=$(basename "$model_dir")
            
            # 计数
            vendor_models[$vendor]=$((vendor_models[$vendor] + 1))
            total_models=$((total_models + 1))
            
            # 获取任务类型目录
            task_dirs=$(find "$model_dir" -mindepth 1 -maxdepth 1 -type d -not -path "*.svn*" 2>/dev/null)
            
            # 用于检查该模型的文档完整性
            model_version_count=0
            model_doc_count=0
            model_word_count=0
            model_pdf_count=0
            
            # 遍历任务类型目录
            while IFS= read -r task_dir; do
                if [ -z "$task_dir" ] || [ ! -d "$task_dir" ] || [[ "$task_dir" == *"/.svn"* ]]; then
                    continue
                fi
                
                # 获取版本目录
                version_dirs=$(find "$task_dir" -mindepth 1 -maxdepth 1 -type d -name "v*" -not -path "*.svn*" 2>/dev/null)
                
                # 遍历版本目录
                while IFS= read -r version_dir; do
                    if [ -z "$version_dir" ] || [ ! -d "$version_dir" ] || [[ "$version_dir" == *"/.svn"* ]]; then
                        continue
                    fi
                    
                    # 计数版本目录
                    model_version_count=$((model_version_count + 1))
                    vendor_versions[$vendor]=$((vendor_versions[$vendor] + 1))
                    total_versions=$((total_versions + 1))
                    
                    # 检查doc文件夹
                    if [ -d "$version_dir/doc" ]; then
                        model_doc_count=$((model_doc_count + 1))
                        vendor_docs[$vendor]=$((vendor_docs[$vendor] + 1))
                        total_docs=$((total_docs + 1))
                        
                        # 检查Word文件
                        word_files=$(find "$version_dir/doc" -maxdepth 1 -type f \( -iname "*.doc" -o -iname "*.docx" \) -not -path "*.svn*" 2>/dev/null)
                        if [ -n "$word_files" ]; then
                            model_word_count=$((model_word_count + 1))
                            vendor_words[$vendor]=$((vendor_words[$vendor] + 1))
                            total_words=$((total_words + 1))
                        fi
                        
                        # 检查PDF文件
                        pdf_files=$(find "$version_dir/doc" -maxdepth 1 -type f -iname "*.pdf" -not -path "*.svn*" 2>/dev/null)
                        if [ -n "$pdf_files" ]; then
                            model_pdf_count=$((model_pdf_count + 1))
                            vendor_pdfs[$vendor]=$((vendor_pdfs[$vendor] + 1))
                            total_pdfs=$((total_pdfs + 1))
                        fi
                    fi
                done <<< "$version_dirs"
            done <<< "$task_dirs"
            
            # 检查模型文档是否完整
            if [ $model_version_count -gt 0 ] && [ $model_version_count -eq $model_doc_count ] && [ $model_doc_count -eq $model_word_count ] && [ $model_doc_count -eq $model_pdf_count ]; then
                vendor_complete[$vendor]=$((vendor_complete[$vendor] + 1))
                total_complete=$((total_complete + 1))
            elif [ $model_version_count -gt 0 ]; then
                vendor_incomplete[$vendor]=$((vendor_incomplete[$vendor] + 1))
                total_incomplete=$((total_incomplete + 1))
                vendor_missing_models[$vendor]="${vendor_missing_models[$vendor]}$model_name"$'\n'
            fi
        done <<< "$model_dirs"
    done <<< "$gpu_dirs"
done

# 输出表格标题
echo ""
print_colored "${BOLD}${CYAN}" "==== 大模型文档完整性报告 ===="
echo ""


# 版本目录与文档统计表格（包含大模型总数）
print_colored "$CYAN" "【版本目录与文档统计】"
printf "%-15s %-12s %-14s %-14s %-14s %-14s\n" "厂商" "大模型总数" "版本目录数" "doc文件夹数" "文档文件数" "doc覆盖率"
printf "%-15s %-12s %-14s %-14s %-14s %-14s\n" "---------------" "------------" "--------------" "--------------" "--------------" "--------------"

# 遍历厂商输出统计数据
for vendor in "${VENDORS[@]}"; do
    # 计算doc覆盖率
    if [ ${vendor_versions[$vendor]} -eq 0 ]; then
        doc_rate="0.0%"
    else
        doc_rate=$(awk "BEGIN {printf \"%.1f%%\", (${vendor_docs[$vendor]}/${vendor_versions[$vendor]})*100}")
    fi
    
    # 计算文档文件总数 (Word + PDF)
    total_doc_files=$((${vendor_words[$vendor]} + ${vendor_pdfs[$vendor]}))
    
    # 输出行
    printf "%-15s %-12s %-14s %-14s %-14s %-14s\n" \
           "$vendor" \
           "${vendor_models[$vendor]}" \
           "${vendor_versions[$vendor]}" \
           "${vendor_docs[$vendor]}" \
           "$total_doc_files" \
           "$doc_rate"
done

# 输出总计行
if [ $total_versions -eq 0 ]; then
    total_doc_rate="0.0%"
else
    total_doc_rate=$(awk "BEGIN {printf \"%.1f%%\", ($total_docs/$total_versions)*100}")
fi

# 计算总文档文件数
total_doc_files=$((total_words + total_pdfs))

printf "%-15s %-12s %-14s %-14s %-14s %-14s\n" "---------------" "------------" "--------------" "--------------" "--------------" "--------------"
printf "%-15s %-12s %-14s %-14s %-14s %-14s\n" \
       "总计" \
       "$total_models" \
       "$total_versions" \
       "$total_docs" \
       "$total_doc_files" \
       "$total_doc_rate"

echo ""
       "$total_docs" \
       "$total_doc_files" \
       "$total_doc_rate" \
       "$total_complete" \
       "$total_complete_rate"

echo ""
# 缺少文档的大模型列表
if [ $total_incomplete -gt 0 ]; then
    print_colored "$CYAN" "【缺少文档的大模型列表】"
    
    for vendor in "${VENDORS[@]}"; do
        if [ ${vendor_incomplete[$vendor]} -gt 0 ]; then
            if [ "$USE_COLOR" = true ]; then
                echo -e "${BOLD}$vendor${NC} (${vendor_incomplete[$vendor]}个):"
            else
                echo "$vendor (${vendor_incomplete[$vendor]}个):"
            fi
            echo -e "${vendor_missing_models[$vendor]}" | sort | uniq | while read -r model; do
                if [ -n "$model" ]; then
                    echo "  - $model"
                fi
            done
            echo ""
        fi
    done
fi

# 总结
print_colored "$CYAN" "【总体结论】"
if [ $total_incomplete -eq 0 ] && [ $total_docs -eq $total_versions ] && [ $total_words -eq $total_versions ] && [ $total_pdfs -eq $total_versions ]; then
    print_colored "$GREEN" "✅ 检查完成，所有大模型文档完整！"
    echo "所有大模型都有完整的文档，版本目录、doc文件夹、Word文件和PDF文件数量均匹配。"
else
    print_colored "$RED" "❌ 检查完成，发现文档不完整问题"
    
    if [ $total_incomplete -gt 0 ]; then
        if [ "$USE_COLOR" = true ]; then
            echo -e "${RED}● 共有 $total_incomplete 个大模型缺少完整文档${NC}"
        else
            echo "● 共有 $total_incomplete 个大模型缺少完整文档"
        fi
    fi
    
    if [ $total_docs -ne $total_versions ]; then
        if [ "$USE_COLOR" = true ]; then
            echo -e "${RED}● 有 $(($total_versions - $total_docs)) 个版本目录缺少doc文件夹${NC}"
        else
            echo "● 有 $(($total_versions - $total_docs)) 个版本目录缺少doc文件夹"
        fi
    fi
fi

echo ""

# 显示使用说明
if [ "$USE_COLOR" = false ]; then
    echo "提示: 使用 --no-color 或 --plain 参数可禁用颜色输出"
fi
