# ORB-SLAM3 Custom Docker
## Aprimoramento de SLAM Monocular com Estimação de Profundidade

ORB-SLAM3 original sem segfault, com EVO instalado.
Depth sintético (MiDaS/DAV2) gerado no Google Colab e importado via volume.

---

## Estrutura

```
orbslam3_custom/
├── Dockerfile              ← ORB-SLAM3 original + EVO
├── docker-compose.yml      ← volumes e configuração
└── scripts/
    └── run_experiment.sh   ← pipeline interativo
```

---

## Setup

```bash
cd orbslam3_custom
xhost +local:docker
docker compose build        # ~20 minutos
docker compose run orbslam3
```

---

## Fluxo de trabalho

```
Google Colab                    Container Docker
    ↓                               ↓
Gerar depth MiDaS/DAV2  →  ~/datasets/tum/<dataset>/depth_*/
Gerar associations.txt  →  ~/datasets/tum/<dataset>/associations_*.txt
                                    ↓
                            run_experiment.sh
                                    ↓
                            ~/orbslam3_results/
                                    ↓
                            evo_ape → RMSE
```

---

## Uso dentro do container

### Pipeline interativo

```bash
/root/scripts/run_experiment.sh
```

Pergunta: dataset → modo → avaliar com EVO?

### Rodar manualmente

```bash
# RGB-D real
rgbd_tum $VOCAB \
  /opt/ORB_SLAM3/Examples/RGB-D/TUM1.yaml \
  /root/datasets/tum/rgbd_dataset_freiburg1_desk \
  /opt/ORB_SLAM3/Examples/RGB-D/associations/fr1_desk.txt

# Monocular
mono_tum $VOCAB \
  /opt/ORB_SLAM3/Examples/Monocular/TUM1.yaml \
  /root/datasets/tum/rgbd_dataset_freiburg1_desk

# DAV2 (associations gerado no Colab)
rgbd_tum $VOCAB \
  /opt/ORB_SLAM3/Examples/RGB-D/TUM1.yaml \
  /root/datasets/tum/rgbd_dataset_freiburg1_desk \
  /root/datasets/tum/rgbd_dataset_freiburg1_desk/associations_dav2_vitl.txt
```

### Avaliar com EVO

```bash
evo_ape tum \
  /root/datasets/tum/rgbd_dataset_freiburg1_desk/groundtruth.txt \
  /root/KeyFrameTrajectory.txt \
  --align --plot
```

---

## Volumes montados

| Host | Container |
|---|---|
| `~/datasets` | `/root/datasets` |
| `~/orbslam3_results` | `/root/results` |
