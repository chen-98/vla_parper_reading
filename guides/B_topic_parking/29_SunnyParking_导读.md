# SunnyParking 导读

> **论文**：SunnyParking: Multi-Shot Trajectory Generation and Motion State Awareness for Human-like Parking  
> **作者**：Jishu Miao, Han Chen, Jiankun Zhai, Qi Liu, Tsubasa Hirakawa, Takayoshi Yamashita, Hironobu Fujiyoshi  
> **版本**：arXiv:2602.21682v1，2026（尚未见正式同行评审版本）  
> **原文**：[本地 PDF](../../papers/B_topic/parking/B29_SunnyParking_2026.pdf) · [arXiv](https://arxiv.org/abs/2602.21682)  
> **建议阅读时间**：35-45 分钟

## 先记住一句话

SunnyParking 不把泊车视为单一的二维曲线回归，而是同时预测 **连续轨迹** 与逐点的 **前进/倒车 motion state**；这样把最容易出错的换挡边界显式化，尤其针对需要多次揉库的 multi-shot parking。

## 它在系统中的位置

输入为四路环视 RGB 图像和已选目标车位的连续 pose `(x, y, yaw)`；输出为长度为 30 的未来 waypoint 序列，以及与每个 waypoint 对齐的前进/倒车状态。它是一个 **视觉条件、目标条件的 imitation-learning trajectory generator**，并不直接输出方向盘/油门，也没有在原文中给出完整交互式闭环成功率。

```text
4 × surround-view RGB ──→ image encoder + lift-splat ──→ BEV spatial feature
                                                            ↑
target slot (x, y, yaw) ─→ Fourier encoding + query fusion ┘
                                                            ↓
                         trajectory decoder ──→ waypoints (x, y, yaw)
                                  │                         ↓
                                  └──────────→ motion decoder → forward / reverse
```

停车中的一个轨迹点只含 `(x, y)` 是不充分的：同一几何位置可能由前进或倒车到达，换挡附近还必须满足零速、曲率、车身朝向和控制可达性。SunnyParking 的中心假设是：**先让模型知道自己正在执行什么运动原语，再要求它拟合几何轨迹。**

## 三个核心设计

### 1. 轨迹分支加 motion-state 分支：把换挡边界变成监督对象

作者从车辆纵向速度得到标签：`v > 0.05 m/s` 为前进、`v < -0.05 m/s` 为倒车、其余为静止。预处理时保留静止作为 maneuver 之间的暂停信息；但实际 motion decoder 只序列化前进/倒车两个方向 primitive，静止由近零速度与平滑性间接处理。

motion branch 会读取 trajectory branch 的隐藏特征，再对目标感知 BEV 特征做 cross-attention。因此它不是一个与轨迹完全独立的分类头，而是回答：**这条正在生成的轨迹在每个时间点应由哪个方向状态执行？**

### 2. Fourier 车位表示：不要把精确目标栅格化

许多停车方法把目标车位画成 BEV heatmap。若 BEV 分辨率为 0.1 m/pixel，车位移动到像素边界附近时会量化跳变，而窄车位和换挡点对厘米级误差很敏感。

SunnyParking 对连续 `(x, y)` 使用多频正余弦 Fourier features、对 yaw 使用 `[sin(yaw), cos(yaw)]`，再用该目标向量调制 spatial query，并从视觉 BEV feature 中查询与该车位相关的区域。它的贡献是 **continuous goal representation + cross-domain attention**，并非单纯把 Fourier encoding 拼到 MLP 输入。

### 3. 只在稳定段平滑 motion state

总损失由 waypoint MSE 和 motion loss 组成。motion loss 包括交叉熵以及 GT-aware smoothness loss：在真值换挡点周围留出容忍窗口，不对预测施加“不要变化”的平滑惩罚；只在非换挡稳定区域压制状态抖动。

这是很合理的小设计。若对全时域强行平滑，模型会把真正应发生的前进/倒车切换抹平；若没有平滑项，则会在犹豫区域产生无意义的方向闪烁。

## 实验该怎么看

数据来自 CARLA 0.9.13 Town04_Opt：16 个目标车位、静态停放车辆、8 名人类使用 Logitech G29 驾驶，最终清洗得到 562 条任务，按 1/2/3/4-shot（0/1/2/3 次换挡）分组。其中 4-shot 占 54%，故任务分布刻意偏向多把泊车。模型用 4 路 `400 × 300` RGB、5 Hz 数据，预测 30 步未来序列。

| 指标 | SunnyParking | 该如何解读 |
|---|---:|---|
| L2 waypoint error | 1.065 m | 略优于改造后的 TransFuser（1.077 m） |
| Fourier trajectory distance | 19.282 | 低于两种基线 |
| Hausdorff distance | 1.169 m | 略高于 TransFuser（1.154 m），不应说它全指标领先 |
| 平均航向误差 | 5.5° | 基线未报告同一项 |
| 换挡点位置平均误差 | 1.152 m | 论文真正想建立的评价接口 |
| motion-state accuracy | 0.838 | 来自完整模型消融，而非闭环成功率 |

最有价值的消融不是总表排名，而是：Fourier 输入下，单轨迹模型的 L2 为 2.863 m；加入扩展轨迹头与 motion branch 后降到 1.065 m。带 motion branch 的完整 BEV 版本为 1.474 m，说明“显式运动状态”与“连续目标表示”各自都有贡献。

反直觉的是 Scheduled Sampling 对简单基线有帮助，却使完整模型从 1.065 m 降至 1.421 m。论文解释为双分支对额外自回归噪声敏感；更保守的解读是：在这个小规模、特定分布数据集上，训练策略的结论仍需跨场景和多随机种子复核。

## 证据边界与局限

- 论文的主要评测是 **开环轨迹和状态预测**。作者明确说仍需要 closed-loop test；不能把较低 L2 或换挡点误差等同于更高停车成功率。
- 场景主要包含静态车辆；行人、交互车辆、遮挡和传感器失效并未形成有力验证。
- 数据规模为 562 条清洗后的 CARLA 人类演示，且 4-shot 占比较高。模型会在一些 1-shot 样例中预测 3-shot maneuver，论文将其归因于数据分布偏斜。
- forward/reverse 是有用但不完整的运动学状态。它没有显式预测 gear、零速持续时间、曲率、转角速度或碰撞可行性；这些仍需要控制器、投影层或闭环约束补齐。
- 论文声称 Fourier 目标编码有很高的理论/实际精度，但最终任务指标仍以米级开环误差报告；“子厘米编码”不等价于整个系统的子厘米规划精度。

## 与前后工作的关系

| 工作 | 主要输出 | SunnyParking 相对其增加了什么 |
|---|---|---|
| E2E Parking | 直接低层控制 | 改为更可检查的轨迹接口，但失去直接闭环控制证据 |
| ParkingE2E | 连续 waypoint | 给每个 waypoint 增加 direction state，聚焦 multi-shot 换挡点 |
| TransParking | 轨迹 + soft target localization | 用连续 Fourier goal 避免 BEV 目标量化，并显式建模 motion state |
| ParkFormer | control + gear token | SunnyParking 的状态更贴近连续轨迹解码，但动态行人/闭环证据较弱 |
| YUKUIv2 | key point + diffusion trajectory | 将 SunnyParking 的换挡状态进一步提升为 key point，再生成多模态连续轨迹 |

它也很适合作为 DriveMA 式 verifiable meta-action 的泊车对照：DriveMA 面向通用驾驶，以可验证语义动作约束轨迹；SunnyParking 已在更具体的泊车任务中给出了前进/倒车这一最基本、最可验证的 maneuver variable。

## 建议精读路线

1. **Figure 1 + Introduction**：确认论文所称“dimensionality deficiency”究竟是缺少 heading 和 motion state，而不是泛泛的轨迹误差问题。
2. **Figure 2 + Section III-A**：画出四相机、BEV、目标车位、轨迹分支和状态分支的数据流。
3. **Section III-B/C**：区分 Fourier feature、target projection、query infusion、cross-attention 四步；不要误读为普通 goal embedding。
4. **Section III-D/E**：检查 trajectory hidden feature 如何注入 motion branch，以及 smoothness mask 为何要在换挡点关闭。
5. **Table I-II + Figure 5**：同时看轨迹误差、换挡点误差、复杂度分组和“1-shot 被预测为 3-shot”的失败样例。
6. **Appendix A**：核对数据的静态环境、起始姿态分布、人工驾驶采集和样本筛选；这是解释结论外推范围的关键。

## 读完后应能回答

- 为什么 multi-shot parking 的 action space 不能只有 `(x, y)` waypoint？
- SunnyParking 的 motion state 是辅助标签、约束，还是可执行的动作？
- Fourier goal encoding 实际解决了 BEV heatmap 的哪类误差？
- 为什么状态平滑项必须在真实换挡附近失效？
- L2 降低能否证明在多把泊车中一定更安全、更少换挡或更高成功率？
- 若迁移到实车，应该补上哪些闭环、车辆运动学和交互场景评测？

## 复现建议

最值得复现的是论文的 **表示假设**，而不是先逐像素复刻网络：在固定的 camera-to-BEV encoder 与 trajectory decoder 上，比较 `(1) 纯连续轨迹`、`(2) 轨迹 + forward/reverse state`、`(3) (2) + shift-aware smoothness`、`(4) (3) + continuous Fourier goal`。除了开环 ADE/FDE/L2，至少报告闭环入位成功率、碰撞/最小间距、最终 pose 误差、换挡次数、换挡位置误差、卡死率、运动学不可行率和推理延迟。

若目标是研究而非复现，下一步应把当前二元 motion state 扩展为 `{gear, intent, subgoal, termination}`，并让 key point 或 diffusion segment 在每个 maneuver 内生成连续、经运动学投影的轨迹。
