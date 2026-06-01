#!/bin/bash
# =============================================================================
# run_experiment.sh — Pipeline ORB-SLAM3 interativo
# Uso: ./run_experiment.sh
# =============================================================================

ORBSLAM3_DIR="/opt/ORB_SLAM3"
VOCAB="$ORBSLAM3_DIR/Vocabulary/ORBvoc.txt"
DATASETS_DIR="/root/datasets/tum"
RESULTS_DIR="/root/results"
RGBD_EXE="$ORBSLAM3_DIR/Examples/RGB-D/rgbd_tum"
MONO_EXE="$ORBSLAM3_DIR/Examples/Monocular/mono_tum"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   ORB-SLAM3 — Pipeline de Experimentos    ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

select_option() {
    local PROMPT=$1; shift; local OPTIONS=("$@")
    echo -e "\n${BOLD}$PROMPT${NC}"
    for i in "${!OPTIONS[@]}"; do
        echo -e "  ${CYAN}[$((i+1))]${NC} ${OPTIONS[$i]}"
    done
    while true; do
        echo -n -e "\n  Escolha [1-${#OPTIONS[@]}]: "
        read CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && \
           [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#OPTIONS[@]}" ]; then
            return $((CHOICE-1))
        fi
        echo -e "${RED}  Opção inválida.${NC}"
    done
}

confirm() {
    echo -n -e "\n${YELLOW}  $1 [s/N]: ${NC}"
    read R; [[ "$R" =~ ^[sS]$ ]]
}

print_banner

# --- Dataset ---
select_option "Dataset:" \
    "fr1/desk  — Escritório, movimento brusco (573 frames)" \
    "fr2/xyz   — Translação suave (3669 frames)"
DATASET_IDX=$?

if [ $DATASET_IDX -eq 0 ]; then
    DATASET_NAME="fr1_desk"
    DATASET_PATH="$DATASETS_DIR/rgbd_dataset_freiburg1_desk"
    GROUNDTRUTH="$DATASET_PATH/groundtruth.txt"
    YAML_RGBD="$ORBSLAM3_DIR/Examples/RGB-D/TUM1.yaml"
    YAML_MONO="$ORBSLAM3_DIR/Examples/Monocular/TUM1.yaml"
    ASSOC_REAL="$ORBSLAM3_DIR/Examples/RGB-D/associations/fr1_desk.txt"
    DISPLAY_NAME="fr1/desk"
else
    DATASET_NAME="fr2_xyz"
    DATASET_PATH="$DATASETS_DIR/rgbd_dataset_freiburg2_xyz"
    GROUNDTRUTH="$DATASETS_DIR/rgbd_dataset_freiburg2_xyz-groundtruth.txt"
    YAML_RGBD="$ORBSLAM3_DIR/Examples/RGB-D/TUM2.yaml"
    YAML_MONO="$ORBSLAM3_DIR/Examples/Monocular/TUM2.yaml"
    ASSOC_REAL="$ORBSLAM3_DIR/Examples/RGB-D/associations/fr2_xyz.txt"
    DISPLAY_NAME="fr2/xyz"
fi

# --- Modo ---
select_option "Modo:" \
    "rgbd_baseline — RGB-D com depth real do sensor" \
    "monocular     — Câmera monocular pura" \
    "midas         — RGB-D com depth MiDaS (gerado no Colab)" \
    "dav2          — RGB-D com depth DAV2 (gerado no Colab)"
MODE_IDX=$?

case $MODE_IDX in
    0) MODE="rgbd_baseline"; MODE_DISPLAY="RGB-D Baseline"; ASSOC="$ASSOC_REAL" ;;
    1) MODE="monocular";     MODE_DISPLAY="Monocular Puro";  ASSOC="" ;;
    2) MODE="midas";         MODE_DISPLAY="RGB-D + MiDaS";
       ASSOC="$DATASET_PATH/associations_midas.txt" ;;
    3) MODE="dav2";          MODE_DISPLAY="RGB-D + DAV2";
       ASSOC="$DATASET_PATH/associations_dav2_vitl.txt" ;;
esac

# --- EVO ---
RUN_EVAL=false
if confirm "Avaliar com EVO após rodar?"; then RUN_EVAL=true; fi

OUTDIR="$RESULTS_DIR/$DATASET_NAME/$MODE"

echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Dataset  : ${CYAN}$DISPLAY_NAME${NC}"
echo -e "  Modo     : ${CYAN}$MODE_DISPLAY${NC}"
echo -e "  Output   : ${CYAN}$OUTDIR${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if ! confirm "Confirmar e iniciar?"; then
    echo -e "\n${YELLOW}  Cancelado.${NC}\n"; exit 0
fi

# --- Verificações ---
echo -e "\n${CYAN}▶ Verificando arquivos...${NC}"
[ -f "$VOCAB" ]        && echo -e "${GREEN}  ✔ Vocabulário${NC}" \
                       || { echo -e "${RED}  ✘ Vocabulário não encontrado${NC}"; exit 1; }
[ -d "$DATASET_PATH" ] && echo -e "${GREEN}  ✔ Dataset${NC}" \
                       || { echo -e "${RED}  ✘ Dataset não encontrado: $DATASET_PATH${NC}"; exit 1; }
if [ -n "$ASSOC" ] && [ "$MODE" != "monocular" ]; then
    [ -f "$ASSOC" ] && echo -e "${GREEN}  ✔ Associations${NC}" \
                    || { echo -e "${RED}  ✘ Associations não encontrado: $ASSOC${NC}"; exit 1; }
fi

# --- Executar ---
mkdir -p "$OUTDIR"
cd /root
rm -f /root/KeyFrameTrajectory.txt /root/CameraTrajectory.txt
START_TIME=$(date +%s)

echo -e "\n${CYAN}▶ Rodando $MODE_DISPLAY — $DISPLAY_NAME...${NC}"

case $MODE in
    rgbd_baseline|midas|dav2)
        "$RGBD_EXE" "$VOCAB" "$YAML_RGBD" "$DATASET_PATH" "$ASSOC"
        ;;
    monocular)
        "$MONO_EXE" "$VOCAB" "$YAML_MONO" "$DATASET_PATH"
        ;;
esac

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# --- Salvar ---
echo -e "\n${CYAN}▶ Salvando resultados...${NC}"
for FILE in KeyFrameTrajectory.txt CameraTrajectory.txt; do
    if [ -f "/root/$FILE" ]; then
        cp "/root/$FILE" "$OUTDIR/$FILE"
        POSES=$(wc -l < "$OUTDIR/$FILE")
        echo -e "${GREEN}  ✔ $FILE — $POSES poses${NC}"
    fi
done
cp "$YAML_RGBD" "$OUTDIR/params.yaml" 2>/dev/null || \
cp "$YAML_MONO" "$OUTDIR/params.yaml" 2>/dev/null || true

# --- EVO ---
if $RUN_EVAL && [ -f "$GROUNDTRUTH" ]; then
    echo -e "\n${CYAN}▶ Avaliando com EVO...${NC}"
    for TRAJ in CameraTrajectory.txt KeyFrameTrajectory.txt; do
        if [ -f "$OUTDIR/$TRAJ" ] && [ $(wc -l < "$OUTDIR/$TRAJ") -gt 5 ]; then
            evo_ape tum "$GROUNDTRUTH" "$OUTDIR/$TRAJ" \
                --align \
                --save_results "$OUTDIR/ate_${TRAJ%.txt}.zip"
            break
        fi
    done
fi

echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔ Concluído em ${ELAPSED}s${NC}"
echo -e "  Arquivos : $OUTDIR"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
