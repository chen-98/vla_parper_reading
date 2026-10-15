# ChauffeurNet 导读

> **论文**：ChauffeurNet: Learning to Drive by Imitating the Best and Synthesizing the Worst  
> **作者**：Mayank Bansal, Alex Krizhevsky, Abhijit Ogale  
> **会议**：RSS 2019  
> **原文**：[本地 PDF](../../papers/A_core/01_ChauffeurNet_2019.pdf) · [官方 PDF](https://www.roboticsproceedings.org/rss15/p31.pdf)  
> **建议阅读时间**：35-45 分钟

## 先记住一句话

ChauffeurNet 的核心不是“用更大的网络模仿更多数据”，而是：**通过合成偏离专家轨迹的坏状态，再用碰撞、越界和几何损失训练恢复能力，使行为克隆真正能在闭环中工作。**

## 它在系统里替换了什么

这不是严格意义上的 raw-sensor-to-control。模型输入是感知与地图模块预先渲染的鸟瞰中间表示，包括道路、限速、交通灯、导航路线、其他交通参与者、ego 历史轨迹等；输出是连续未来轨迹点、朝向和速度，最后交给车辆动力学控制器执行。

```text
感知/地图/路线提供结构化 BEV
          ↓
FeatureNet + AgentRNN
          ↓
未来位置、朝向、速度、ego box
          ↓
传统控制优化器 → steering / brake
```

因此它是 **learned planner replacement + traditional controller**。这个接口对规划工程师很重要：论文明确反对直接把车型相关的 steering/acceleration 当成唯一学习目标，认为轨迹更容易跨车辆复用和施加动力学约束。

## 方法主线

### 1. 自回归轨迹生成

FeatureNet 编码所有 BEV 输入；AgentRNN 逐步预测未来位置热力图、车辆占据框、亚像素位置、朝向和速度。显式的二维 memory 会累积已经预测过的位置，帮助后续 waypoint 解码。Road Mask Network 和 PerceptionRNN 作为辅助任务，分别预测可行驶区域和其他交通参与者未来占据。

阅读 Figure 3 和 Figure 4 时，重点看两点：共享特征如何同时服务 ego planning 与 scene prediction；输出为何是可执行轨迹，而不是驾驶意图分类。

### 2. Past motion dropout

如果训练时始终输入专家历史轨迹，网络可能通过“专家已经减速”判断应该停车，而不是看见停车标志本身。闭环部署后，历史来自模型自身，这种捷径会失效。论文随机抹去过去轨迹，只保留当前位置，迫使模型使用场景中的因果线索。

这是一个很值得迁移到现代 E2E 的思想：**历史状态既有信息，也可能泄漏专家行为。**

### 3. Synthesizing the worst

作者对专家轨迹中点做位置和航向扰动，再平滑连接原起终点，产生偏离车道、接近碰撞等真实日志很少包含的状态。训练时不仅拟合专家，还加入：

- collision loss：惩罚预测 ego box 与其他物体占据重叠；
- on-road loss：惩罚车辆框落在非道路区域；
- geometry loss：约束预测轨迹与目标几何形态；
- future-object/road-mask 辅助损失；
- imitation dropout：部分样本关闭模仿项，让环境约束真正产生梯度。

它不是 RL：没有让策略在线探索并用 reward 更新，而是在专家数据周围进行受控的离线状态扩展。

## 实验应该怎么看

训练集约 2600 万样本，相当于约 60 天连续驾驶。闭环消融设置包括绕过路边停车、轨迹偏移恢复和跟随慢车。Figure 6 的关键结论不是绝对成功率，而是组件间因果关系：

- 纯模仿模型 M0 在偏移恢复场景中完全失败；
- 加入 perturbation 后，低速偏移能够恢复；
- 环境损失与 imitation dropout 组合的 M4 在绕障和恢复上明显最好；
- M4 在极端追赶慢车时也会过于激进，说明约束损失不能替代交互式数据。

最重要的证据是 Figure 7：M0 的 open-loop waypoint L2 误差更低，但 M4 的 closed-loop 驾驶显著更好。它非常早就明确说明：**模仿误差不是 planner 质量的充分指标。**

论文还给出实车闭环演示，但不是大规模道路统计。模型在 P100 上约 160 ms，AgentRNN 是主要耗时部分。

## 局限与阅读警惕

- 输入依赖高质量地图、感知和跟踪，因此不是完整 perception-to-planning E2E。
- 闭环仿真主要重放日志环境，其他交通参与者并非充分 reactive。
- 20 cm/pixel、64 m 前向视野限制高速并线和路口观察。
- U-turn、cul-de-sac、低速挪车等长时域行为覆盖不足。
- 有时生成不满足转弯半径的轨迹，说明神经轨迹输出仍需运动学投影或控制约束。
- 稀有交互中可能过于激进；作者自己指出需要更充分的仿真探索。

## 对后续论文的影响

ChauffeurNet 奠定了三条长期有效的经验：

1. planner 应学习恢复，而不只是复现专家中心轨迹；
2. 中间轨迹表示是 learned planning 与传统控制之间的实用接口；
3. 必须用闭环行为判断模型，不能只看 open-loop displacement。

Learning by Cheating 会把“特权结构化表示”变成教师；TransFuser 会把输入推进到原始 RGB/LiDAR；nuPlan 则把闭环评价正式变成公共 benchmark。

## 建议精读路线

1. Abstract + Introduction：理解为什么 3000 万样本仍不能解决 covariate shift。
2. Figure 2-4：搞清输入、输出、AgentRNN 和辅助任务。
3. Section IV-V：重点读 past motion dropout、trajectory perturbation 与环境损失。
4. Figure 6-7：比较闭环表现与 open-loop L2 的矛盾。
5. Failure Modes：把每个失败映射到视野、数据、表示或运动学约束。

## 读完后应能回答

- 为什么 perturb expert trajectory 比单纯增加正常驾驶数据更有价值？
- imitation dropout 与降低 imitation loss 权重有什么区别？
- 为什么输出轨迹比直接输出控制更适合作为规划接口？
- 如果迁移到多把泊车，扰动应该作用于 pose、gear/motion state，还是整个 maneuver sequence？
- 论文的 closed-loop 证据距离真实交互式道路闭环还差什么？

## 复现建议

不建议原样复刻整套旧架构。更值得复现的是最小实验：在现有 waypoint planner 上增加 pose/heading perturbation、碰撞/越界约束和 history dropout，然后比较 open-loop L2、闭环恢复率、碰撞率与卡死率。对泊车可进一步按前进/倒车分段扰动，并把换挡正确性纳入恢复指标。
