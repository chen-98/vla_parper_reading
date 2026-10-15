# TransFuser 导读

> **论文**：TransFuser: Imitation with Transformer-Based Sensor Fusion for Autonomous Driving  
> **作者**：Kashyap Chitta, Aditya Prakash, Bernhard Jaeger, Zehao Yu, Katrin Renz, Andreas Geiger  
> **版本**：IEEE TPAMI 2023（CVPR 2021 工作的扩展版）  
> **原文**：[本地 PDF](../../papers/A_core/04_TransFuser_2023.pdf) · [arXiv](https://arxiv.org/abs/2205.15997) · [代码/项目](https://github.com/autonomousvision/transfuser)  
> **建议阅读时间**：40-50 分钟

## 先记住一句话

TransFuser 用多尺度 Transformer 在 RGB 透视特征与 LiDAR BEV 特征之间做全局融合，再自回归生成局部 waypoint；它证明 **E2E 驾驶中的传感器融合需要场景级上下文，而不仅是晚期拼接或几何投影。**

## 系统定位

输入是三路相机拼接图、单帧 LiDAR BEV、稀疏 GPS goal；输出是 ego 坐标系中的 4 个连续 waypoint，PID 再转换为 steer/throttle/brake。训练采用行为克隆和辅助感知任务，评价在 CARLA 闭环完成。

```text
RGB image branch  ─┐
                   ├─ multi-scale Transformer fusion → compact scene feature
LiDAR BEV branch ──┘                                  ↓
GPS target -------------------------------------→ GRU waypoints
                                                        ↓
                                                      PID
```

它是 **raw-sensor E2E planner + classical controller**，不是直接控制模型，也不是 UniAD 式完整任务 query 链。所谓 E2E 主要指从传感器与 route goal 到局部计划联合学习。

## 架构要点

### 1. 输入与输出表示

LiDAR 被离散为 32 m × 32 m、0.125 m 分辨率的两层高度 histogram，并额外拼接 rasterized goal channel。RGB 来自左/前/右三相机，组合成约 132° FOV。模型只使用当前单帧观测。

轨迹表示为 4 个二维 waypoint。GRU 预测的是相邻 waypoint 的增量，再累加得到完整局部轨迹。GPS goal 同时进入编码侧和 GRU，确保全局意图直接影响规划解码。

### 2. 多尺度跨模态融合

Figure 2 是必看图。RGB 与 LiDAR 分别经过卷积 backbone；每个尺度的二维 feature map 被展平成 token 集合，加入位置编码后共同进入 Transformer。输出再拆回两个分支，与原特征残差相加。浅层与深层都进行这种双向融合。

与简单 late fusion 相比，它让某个图像区域直接关注任意 LiDAR BEV 单元；与显式几何投影相比，它不依赖固定 correspondence，能学习交通灯、车辆、路口形态与可行驶空间之间的全局关系。

### 3. Waypoint decoder 与辅助任务

融合后的两个 512 维向量相加，经 MLP 压缩到 64 维，初始化单层 GRU，逐步输出 waypoint。训练主损失是 waypoint L1；图像分支增加 depth/semantic segmentation，BEV 分支增加 HD-map 与 vehicle detection。

辅助任务不是最终 planner 输出，但给传感器特征增加几何和语义监督。消融显示全部移除辅助任务会明显降低 Route Completion，而单独移除某一项的效果落在训练 seed 方差范围内。

## 隐藏在“端到端”之外的工程组件

TransFuser 仍使用 PID、creeping 和 safety heuristic。车辆停滞超过 55 秒后会短暂设定 4 m/s 目标速度；若前方 LiDAR 区域有点，则安全规则覆盖 creeping。TPAMI 版还讨论更广泛的全局 safety heuristic。

这不是瑕疵，而是阅读时必须明确的归因边界：模型、控制器、恢复规则和 safety override 共同决定闭环分数。复现时若遗漏这些代码细节，论文分数不可比。

## 实验结论

作者为低成本消融提出 Longest6：6 个城镇各选最长 6 条路线，并加入高密度交通、天气/光照和 adversarial scenarios。主要指标是 Route Completion、Infraction Score 和二者组合的 Driving Score。

在 Longest6 中，TransFuser 的 Driving Score 为 47.30，明显高于 late fusion 22.47 和 geometric fusion 27.32；但 image-only Latent TransFuser 的 Route Completion 反而最高，说明 LiDAR 并非对所有指标都单调增益。官方 CARLA Leaderboard 上 TransFuser 达到 DS 61.18。

单模型在 RTX 3090 上约 27.6 ms/frame，包括预处理、推理和 PID，具备实时性。作者也强调不同训练 seed 的波动很大；只重复同一 checkpoint 的 simulator rollout 不足以描述模型方差。

## 局限与失败模式

- 高密度交通中换道和无保护转弯容易连续碰撞；车辆碰撞率约为 expert 的 9 倍。
- 单帧输入没有显式时序历史，动态意图主要靠瞬时观测推断。
- 只有 4 个短时 waypoint，长时行为由 GPS target、数据偏置和控制启发式间接决定。
- 对 CARLA expert、地图、传感器配置和 PID 有较强依赖。
- Transformer 提升的是融合能力，不自动解决行为多模态、交互预测或运动学约束。
- 安全规则和 ensemble 会显著改变成绩，比较时必须分离模型本体与部署包装。

## 与前后工作的关系

ChauffeurNet/LBC 使用结构化或 privileged BEV 降低感知难度；TransFuser 把最终 policy 推进到原始 RGB/LiDAR。TCP 随后证明只用单目相机，通过 trajectory/control 双表示也能获得更强闭环成绩。UniAD/VAD 则不再只研究传感器融合，而是重构 perception、prediction、planning 的任务接口。

对泊车而言，TransFuser 的直接价值是 surround-view + BEV/occupancy 融合范式；但其短轨迹、前向驾驶与单向 gear 假设不能直接覆盖 multi-shot parking。需要额外建模目标车位、挡位/运动状态、长时 maneuver 与车辆几何。

## 建议精读路线

1. Figure 1：理解为什么全局跨模态关系比局部融合重要。
2. Figure 2 + Section 3.2-3.5：画出坐标系、四级融合、GRU 与 PID。
3. Figure 3：区分训练辅助任务与部署输出。
4. Table 1-3：比较 DS、RC、IS，不要只看总排名。
5. Limitations + Figure 5：观察换道/无保护转弯为何失败。
6. Section 4.12：看 auxiliary tasks、backbone、token resolution 与 seed 方差。

## 读完后应能回答

- Transformer fusion 相比 late/geometric fusion 解决的核心信息瓶颈是什么？
- 为什么 Latent TransFuser 能有很高 RC，却不一定更安全？
- 4-waypoint + PID 接口把哪些问题交给了 controller？
- creeping/safety heuristic 对“端到端”成绩归因有何影响？
- 若迁移到泊车，应把 gear、slot pose 和 multi-shot history 放在输入、token 还是 decoder 中？

## 复现建议

工程上值得复现。优先使用官方代码和对应 CARLA/container 版本，先复现单模型而非 ensemble。固定 expert 数据、PID、creeping 和 safety rule，只替换 fusion 模块；至少报告 3 个 training seeds、每 seed 多次闭环、DS/RC/IS、推理延迟和换道/路口切片。泊车迁移时建议保留 BEV fusion，但将 4-point GRU 换成 gear-aware multi-segment trajectory decoder。
