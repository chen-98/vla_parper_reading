# Learning by Cheating 导读

> **论文**：Learning by Cheating  
> **作者**：Dian Chen, Brady Zhou, Vladlen Koltun, Philipp Krähenbühl  
> **会议**：CoRL 2020（PMLR 100）  
> **原文**：[本地 PDF](../../papers/A_core/02_Learning_by_Cheating_2020.pdf) · [论文页](https://proceedings.mlr.press/v100/chen20a.html) · [代码](https://github.com/dianchen96/LearningByCheating)  
> **建议阅读时间**：30-40 分钟

## 先记住一句话

Learning by Cheating（LBC）把驾驶学习拆成两步：**先让拥有仿真真值的 privileged agent 学会规划，再让只看相机的 sensorimotor agent 在自身访问到的状态上模仿这个教师。**

## 它真正解决的是什么

LBC 的主要贡献不是一个新的 waypoint decoder，而是一种训练分解：把“学会驾驶行为”和“从图像中看懂场景”部分解耦。最终部署模型只输入单目 RGB、当前速度和高层导航命令，不使用 privileged information；但训练阶段可以反复询问拥有真值 BEV 的教师。

```text
阶段 1：专家轨迹 → privileged BEV planner → waypoint policy
阶段 2：RGB student rollout → privileged planner 查询标签 → student waypoint policy
最终：RGB + speed + command → waypoints → PID → control
```

从系统角色看，它是 **sensor-to-trajectory policy 的训练范式**，不是统一 perception-prediction-planning 架构。输出仍是连续 waypoint，低层控制由两个 PID 完成。

## 三个关键设计

### 1. Privileged agent 先把“行动”学清楚

教师看到 7 通道真值地图，包括道路、车道、车辆、行人和三种交通灯状态。它根据 BEV、速度和导航命令预测 K 个 waypoint heatmap，经 soft-argmax 得到连续坐标，并用专家未来位置做 L1 监督。

由于输入和输出都在 BEV 中，旋转与平移增强非常自然：移动地图的同时变换 waypoint，就能合成偏离车道或航向错误的状态。这个思想和 ChauffeurNet 的 trajectory perturbation 同源，但 LBC 把恢复知识先集中到教师中。

### 2. Sensorimotor student 学“看见教师看见的东西”

学生使用 RGB 与速度，结构与教师相似，也输出 heatmap/waypoint。相机坐标中的 waypoint 通过固定透视变换映射到车辆坐标，与教师输出做 L1 模仿。

论文所谓 white-box supervision，是教师在同一状态下为所有导航分支都提供标签，而不只监督专家实际走过的命令。例如专家左转时，学生仍可获得“若现在右转应怎么走”的训练信号。这是一种高容量反事实数据增强。

### 3. On-policy DAgger 处理分布偏移

仅在专家状态上离线模仿仍会失败。LBC 让学生在 CARLA 中实际 rollout，再由 privileged agent 对学生访问到的状态给出 waypoint 标签。它将 DAgger 的 oracle 从人工/规则专家换成了已训练的 privileged policy。

这一步是 LBC 相比普通 knowledge distillation 更关键的地方：教师不仅提供更丰富标签，还覆盖学生自己的错误分布。

## 规划与控制接口

教师和学生都预测 waypoint；纵向 PID 根据 waypoint 间距估计目标速度，横向 PID 对所有 waypoint 拟合圆弧，再选取弧上目标点计算 steering。圆弧拟合用于平滑单个 waypoint 的误差。

这里应看到一个工程折中：学习模块负责语义和局部几何，传统 controller 负责动作执行；但 waypoint 的时间标定、弯道跟踪误差和 PID 参数仍会直接影响闭环成绩。

## 实验结论怎么读

Table 1 是全文最重要的消融：

| 训练方式 | CoRL2017 navigation 成功率 |
|---|---:|
| 直接训练 sensorimotor policy | 20 |
| 普通两阶段 | 16 |
| 两阶段 + on-policy | 64 |
| 两阶段 + white-box | 96 |
| 两阶段 + white-box + on-policy | 100 |

结论不是“两阶段天然有效”，而是：**普通蒸馏几乎没有收益；全分支监督与学生闭环状态采样才是提升来源。**

论文在 CARLA 0.9.5 的 CoRL2017 和 NoCrash benchmark 上显著领先，并将多数条件下的违章频率降低一个数量级。但 Table 3 也揭示 simulator version sensitivity：换到 CARLA 0.9.6 后，密集交通的测试成功率明显下降。这提醒我们不要把某一模拟器版本上的 100% 当作已解决通用驾驶。

## 局限与阅读警惕

- 最终模型虽不作弊，但训练依赖仿真真值、可查询教师和大量 on-policy rollout。
- 教师行为上限受 hand-crafted autopilot 与 privileged policy 限制。
- 只使用单目图像与较粗的高层命令，复杂交互和长时规划能力有限。
- waypoint + PID 将一部分性能归因留在控制器中，不是完全可学习控制。
- 结果全部来自 CARLA；论文只说可结合 sim-to-real，并没有实车证明。
- “white-box”在这里指可查询所有 command branches，不是现代意义上的可解释模型内部机制。

## 与前后工作的关系

ChauffeurNet 通过离线扰动训练恢复；LBC 进一步用 privileged teacher + DAgger 覆盖学生状态。之后许多 CARLA 方法继续采用 privileged expert、BEV teacher、policy distillation 或 feature/value supervision。TCP 直接使用 RL privileged expert Roach 进行特征和值蒸馏；TransFuser 则重点升级了 RGB/LiDAR 融合架构。

对泊车而言，LBC 的启发很直接：可先用传统 Hybrid A*/优化器或真值 BEV planner 训练一个“作弊教师”，再让视觉学生模仿；更进一步，教师应对学生产生的错误位姿、错误挡位和失败 maneuver 提供纠正，而不只蒸馏正常单把轨迹。

## 建议精读路线

1. Figure 1：先理解两阶段训练闭环。
2. Section 2.1-2.2：比较教师/学生的坐标系、heatmap 与监督信号。
3. Section 2.3：确认 waypoint 如何被 PID 转成控制。
4. Table 1：分离 two-stage、white-box 和 on-policy 的真实贡献。
5. Table 2-3 + Figure 5：看成功率、违章和模拟器版本敏感性。

## 读完后应能回答

- 为什么普通 teacher-student distillation 并没有优于直接训练？
- white-box all-branch supervision 为什么可以视为反事实数据增强？
- LBC 与 DAgger 的关系是什么，oracle 来自哪里？
- privileged teacher 的错误会如何传给学生？
- 在泊车中，教师应该输出整条轨迹、关键点，还是 maneuver/gear + 轨迹层级标签？

## 复现建议

建议复现训练逻辑而不是旧视觉网络：用现有 BEV/传统 planner 作为教师，比较 offline distillation、all-mode supervision、student rollout relabeling 三种设置。指标至少包括闭环成功率、恢复率、碰撞/越界、换挡错误和 student-teacher disagreement，而不是只看 waypoint L1。
