$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $PSScriptRoot
$papersRoot = Join-Path $workspace 'papers'

$items = @(
    @{ Id='A01'; Tier='A'; Topic='A_core'; File='01_ChauffeurNet_2019.pdf'; Url='https://www.roboticsproceedings.org/rss15/p31.pdf' },
    @{ Id='A02'; Tier='A'; Topic='A_core'; File='02_Learning_by_Cheating_2020.pdf'; Url='https://proceedings.mlr.press/v100/chen20a/chen20a.pdf' },
    @{ Id='A03'; Tier='A'; Topic='A_core'; File='03_nuPlan_2021.pdf'; Url='https://arxiv.org/pdf/2106.11810' },
    @{ Id='A04'; Tier='A'; Topic='A_core'; File='04_TransFuser_2023.pdf'; Url='https://arxiv.org/pdf/2205.15997' },
    @{ Id='A05'; Tier='A'; Topic='A_core'; File='05_TCP_2022.pdf'; Url='https://proceedings.neurips.cc/paper_files/paper/2022/file/286a371d8a0a559281f682f8fbf89834-Paper-Conference.pdf' },
    @{ Id='A06'; Tier='A'; Topic='A_core'; File='06_PlanT_2022.pdf'; Url='https://arxiv.org/pdf/2210.14222' },
    @{ Id='A07'; Tier='A'; Topic='A_core'; File='07_ST-P3_2022.pdf'; Url='https://www.ecva.net/papers/eccv_2022/papers_ECCV/papers/136980522.pdf' },
    @{ Id='A08'; Tier='A'; Topic='A_core'; File='08_UniAD_2023.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2023/papers/Hu_Planning-Oriented_Autonomous_Driving_CVPR_2023_paper.pdf' },
    @{ Id='A09'; Tier='A'; Topic='A_core'; File='09_VAD_2023.pdf'; Url='https://openaccess.thecvf.com/content/ICCV2023/papers/Jiang_VAD_Vectorized_Scene_Representation_for_Efficient_Autonomous_Driving_ICCV_2023_paper.pdf' },
    @{ Id='A10'; Tier='A'; Topic='A_core'; File='10_Bench2Drive_2024.pdf'; Url='https://proceedings.neurips.cc/paper_files/paper/2024/file/017761f94a1cd66d01c041aff85492c4-Paper-Datasets_and_Benchmarks_Track.pdf' },
    @{ Id='A11'; Tier='A'; Topic='A_core'; File='11_NAVSIM_2024.pdf'; Url='https://proceedings.neurips.cc/paper_files/paper/2024/file/32768f7faf1995026ef9821c696f3404-Paper-Datasets_and_Benchmarks_Track.pdf' },
    @{ Id='A12'; Tier='A'; Topic='A_core'; File='12_WOD-E2E_2025.pdf'; Url='https://arxiv.org/pdf/2510.26125' },
    @{ Id='A13'; Tier='A'; Topic='A_core'; File='13_Behavior_Transformers_2022.pdf'; Url='https://proceedings.neurips.cc/paper_files/paper/2022/file/90d17e882adbdda42349db6f50123817-Paper-Conference.pdf' },
    @{ Id='A14'; Tier='A'; Topic='A_core'; File='14_Diffusion_Policy_2023.pdf'; Url='https://www.roboticsproceedings.org/rss19/p026.pdf' },
    @{ Id='A15'; Tier='A'; Topic='A_core'; File='15_VADv2_2026.pdf'; Url='https://proceedings.iclr.cc/paper_files/paper/2026/file/70925fe2336ae05917c817d5e4660ab5-Paper-Conference.pdf' },
    @{ Id='A16'; Tier='A'; Topic='A_core'; File='16_Diffusion_Planner_2025.pdf'; Url='https://proceedings.iclr.cc/paper_files/paper/2025/file/5c0cd43063f087eb32e572d040a19cd2-Paper-Conference.pdf' },
    @{ Id='A17'; Tier='A'; Topic='A_core'; File='17_DiffusionDrive_2025.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2025/papers/Liao_DiffusionDrive_Truncated_Diffusion_Model_for_End-to-End_Autonomous_Driving_CVPR_2025_paper.pdf' },
    @{ Id='A18'; Tier='A'; Topic='A_core'; File='18_LMDrive_2024.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2024/papers/Shao_LMDrive_Closed-Loop_End-to-End_Driving_with_Large_Language_Models_CVPR_2024_paper.pdf' },
    @{ Id='A19'; Tier='A'; Topic='A_core'; File='19_DriveVLM_2024.pdf'; Url='https://arxiv.org/pdf/2402.12289' },
    @{ Id='A20'; Tier='A'; Topic='A_core'; File='20_SimLingo_2025.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2025/papers/Renz_SimLingo_Vision-Only_Closed-Loop_Autonomous_Driving_with_Language-Action_Alignment_CVPR_2025_paper.pdf' },
    @{ Id='A21'; Tier='A'; Topic='A_core'; File='21_AutoVLA_2025.pdf'; Url='https://arxiv.org/pdf/2506.13757' },
    @{ Id='A22'; Tier='A'; Topic='A_core'; File='22_ReCogDrive_2026.pdf'; Url='https://proceedings.iclr.cc/paper_files/paper/2026/file/ff7bf6014f7826da531aa50f4538ee19-Paper-Conference.pdf' },
    @{ Id='A23'; Tier='A'; Topic='A_core'; File='23_Poutine_2025.pdf'; Url='https://arxiv.org/pdf/2506.11234' },
    @{ Id='A24'; Tier='A'; Topic='A_core'; File='24_EMMA_2025.pdf'; Url='https://arxiv.org/pdf/2410.23262' },
    @{ Id='A25'; Tier='A'; Topic='A_core'; File='25_DriveMA_2026.pdf'; Url='https://arxiv.org/pdf/2605.31271' },

    @{ Id='B01'; Tier='B'; Topic='planning_foundations'; File='B01_Deep_Imitative_Models_2020.pdf'; Url='https://arxiv.org/pdf/1810.06544' },
    @{ Id='B02'; Tier='B'; Topic='e2e_driving'; File='B02_NEAT_2021.pdf'; Url='https://openaccess.thecvf.com/content/ICCV2021/papers/Chitta_NEAT_Neural_Attention_Fields_for_End-to-End_Autonomous_Driving_ICCV_2021_paper.pdf' },
    @{ Id='B03'; Tier='B'; Topic='e2e_driving'; File='B03_ThinkTwice_2023.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2023/papers/Jia_Think_Twice_Before_Driving_Towards_Scalable_Decoders_for_End-to-End_Autonomous_CVPR_2023_paper.pdf' },
    @{ Id='B04'; Tier='B'; Topic='e2e_driving'; File='B04_DriveAdapter_2023.pdf'; Url='https://openaccess.thecvf.com/content/ICCV2023/papers/Jia_DriveAdapter_Breaking_the_Coupling_Barrier_of_Perception_and_Planning_in_ICCV_2023_paper.pdf' },
    @{ Id='B05'; Tier='B'; Topic='e2e_driving'; File='B05_PPAD_2024.pdf'; Url='https://www.ecva.net/papers/eccv_2024/papers_ECCV/papers/05165.pdf' },
    @{ Id='B06'; Tier='B'; Topic='e2e_driving'; File='B06_DriveTransformer_2025.pdf'; Url='https://proceedings.iclr.cc/paper_files/paper/2025/file/a7afc9957f1190223763b6ea93218f98-Paper-Conference.pdf' },
    @{ Id='B07'; Tier='B'; Topic='e2e_driving'; File='B07_Hydra-MDP_2024.pdf'; Url='https://arxiv.org/pdf/2406.06978' },
    @{ Id='B08'; Tier='B'; Topic='world_model_rl'; File='B08_LAW_2025.pdf'; Url='https://proceedings.iclr.cc/paper_files/paper/2025/file/6aa4967920e495e90aeeaa3acf18d019-Paper-Conference.pdf' },
    @{ Id='B09'; Tier='B'; Topic='world_model_rl'; File='B09_WoTE_2025.pdf'; Url='https://arxiv.org/pdf/2504.01941' },
    @{ Id='B10'; Tier='B'; Topic='world_model_rl'; File='B10_GenAD_2024.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2024/papers/Yang_Generalized_Predictive_Model_for_Autonomous_Driving_CVPR_2024_paper.pdf' },
    @{ Id='B11'; Tier='B'; Topic='parking'; File='B11_ParkingWorld_2026.pdf'; Url='https://arxiv.org/pdf/2605.25029' },
    @{ Id='B12'; Tier='B'; Topic='world_model_rl'; File='B12_Doe-1_2024.pdf'; Url='https://arxiv.org/pdf/2412.09627' },
    @{ Id='B13'; Tier='B'; Topic='world_model_rl'; File='B13_Think2Drive_2024.pdf'; Url='https://www.ecva.net/papers/eccv_2024/papers_ECCV/papers/06129.pdf' },
    @{ Id='B14'; Tier='B'; Topic='world_model_rl'; File='B14_RAD_2025.pdf'; Url='https://papers.neurips.cc/paper_files/paper/2025/file/2ed3a566a0af6dcec424b988f1880ecc-Paper-Conference.pdf' },
    @{ Id='B15'; Tier='B'; Topic='world_model_rl'; File='B15_Raw2Drive_2025.pdf'; Url='https://arxiv.org/pdf/2505.16394' },
    @{ Id='B16'; Tier='B'; Topic='diffusion_planning'; File='B16_Diffusion-ES_2024.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2024/papers/Yang_Diffusion-ES_Gradient-free_Planning_with_Diffusion_for_Autonomous_and_Instruction-guided_Driving_CVPR_2024_paper.pdf' },
    @{ Id='B17'; Tier='B'; Topic='diffusion_planning'; File='B17_GoalFlow_2025.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2025/papers/Xing_GoalFlow_Goal-Driven_Flow_Matching_for_Multimodal_Trajectories_Generation_in_End-to-End_CVPR_2025_paper.pdf' },
    @{ Id='B18'; Tier='B'; Topic='diffusion_planning'; File='B18_GuideFlow_2026.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2026/papers/Liu_GuideFlow_Constraint-Guided_Flow_Matching_for_Planning_in_End-to-End_Autonomous_Driving_CVPR_2026_paper.pdf' },
    @{ Id='B19'; Tier='B'; Topic='diffusion_planning'; File='B19_WAM-Flow_2026.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2026/papers/Xu_WAM-Flow_Parallel_Coarse-to-Fine_Motion_Planning_via_Discrete_Flow_Matching_for_CVPR_2026_paper.pdf' },
    @{ Id='B20'; Tier='B'; Topic='diffusion_planning'; File='B20_PlannerRFT_2026.pdf'; Url='https://openaccess.thecvf.com/content/CVPR2026/papers/Li_PlannerRFT_Reinforcing_Diffusion_Planners_through_Closed-Loop_and_Sample-Efficient_Fine-Tuning_CVPR_2026_paper.pdf' },
    @{ Id='B21'; Tier='B'; Topic='diffusion_planning'; File='B21_Hyper_Diffusion_Planner_2026.pdf'; Url='https://arxiv.org/pdf/2602.22801' },
    @{ Id='B22'; Tier='B'; Topic='action_representation'; File='B22_VQ-BeT_2024.pdf'; Url='https://arxiv.org/pdf/2403.03181' },
    @{ Id='B23'; Tier='B'; Topic='action_representation'; File='B23_ACT_2023.pdf'; Url='https://www.roboticsproceedings.org/rss19/p016.pdf' },
    @{ Id='B24'; Tier='B'; Topic='action_representation'; File='B24_Trajectory_Transformer_2021.pdf'; Url='https://proceedings.neurips.cc/paper/2021/file/099fe6b0b444c23836c4a5d07346082b-Paper.pdf' },
    @{ Id='B25'; Tier='B'; Topic='parking'; File='B25_E2E_Parking_2024.pdf'; Url='https://raw.githubusercontent.com/qintonguav/e2e-parking-carla/master/resource/E2E_APA_IV24_final.pdf' },
    @{ Id='B26'; Tier='B'; Topic='parking'; File='B26_ParkingE2E_2024.pdf'; Url='https://arxiv.org/pdf/2408.02061' },
    @{ Id='B27'; Tier='B'; Topic='parking'; File='B27_E2E_Parking_Dataset_2025.pdf'; Url='https://arxiv.org/pdf/2504.10812' },
    @{ Id='B28'; Tier='B'; Topic='parking'; File='B28_TransParking_2025.pdf'; Url='https://arxiv.org/pdf/2503.06071' },
    @{ Id='B29'; Tier='B'; Topic='parking'; File='B29_SunnyParking_2026.pdf'; Url='https://arxiv.org/pdf/2602.21682' },
    @{ Id='B30'; Tier='B'; Topic='parking'; File='B30_YUKUIv2_2026.pdf'; Url='https://www.jstage.jst.go.jp/article/transinf/advpub/0/advpub_2026DRL0001/_pdf/-char/en' },
    @{ Id='B31'; Tier='B'; Topic='parking'; File='B31_ParkFormer_2025.pdf'; Url='https://arxiv.org/pdf/2506.16856' },
    @{ Id='B32'; Tier='B'; Topic='parking'; File='B32_ParkingTransformer_2026.pdf'; Url='https://arxiv.org/pdf/2606.17082' },
    @{ Id='B33'; Tier='B'; Topic='driving_vla'; File='B33_DriveLM_2024.pdf'; Url='https://arxiv.org/pdf/2312.14150' },
    @{ Id='B34'; Tier='B'; Topic='driving_vla'; File='B34_DriveMLM_2025.pdf'; Url='https://link.springer.com/content/pdf/10.1007/s44267-025-00095-w.pdf' },
    @{ Id='B35'; Tier='B'; Topic='driving_vla'; File='B35_ORION_2025.pdf'; Url='https://openaccess.thecvf.com/content/ICCV2025/papers/Fu_ORION_A_Holistic_End-to-End_Autonomous_Driving_Framework_by_Vision-Language_Instructed_ICCV_2025_paper.pdf' },
    @{ Id='B36'; Tier='B'; Topic='driving_vla'; File='B36_Drive-R1_2025.pdf'; Url='https://arxiv.org/pdf/2506.18234' },
    @{ Id='B37'; Tier='B'; Topic='driving_vla'; File='B37_NoRD_2026.pdf'; Url='https://arxiv.org/pdf/2602.21172' },
    @{ Id='B38'; Tier='B'; Topic='driving_vla'; File='B38_LinkVLA_2026.pdf'; Url='https://arxiv.org/pdf/2603.01441' },
    @{ Id='B39'; Tier='B'; Topic='driving_vla'; File='B39_DriveVLA-W0_2026.pdf'; Url='https://proceedings.iclr.cc/paper_files/paper/2026/file/0d70423f59c5fdd24f0dd3fa52e34623-Paper-Conference.pdf' },
    @{ Id='B40'; Tier='B'; Topic='parking'; File='B40_CAA-Policy_2025.pdf'; Url='https://arxiv.org/pdf/2509.11090' }
)

$folders = @(
    (Join-Path $papersRoot 'A_core'),
    (Join-Path $papersRoot 'B_topic\planning_foundations'),
    (Join-Path $papersRoot 'B_topic\e2e_driving'),
    (Join-Path $papersRoot 'B_topic\world_model_rl'),
    (Join-Path $papersRoot 'B_topic\diffusion_planning'),
    (Join-Path $papersRoot 'B_topic\action_representation'),
    (Join-Path $papersRoot 'B_topic\parking'),
    (Join-Path $papersRoot 'B_topic\driving_vla'),
    (Join-Path $papersRoot 'B_topic\benchmarks'),
    (Join-Path $papersRoot 'metadata')
)
$folders | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

$headers = @{
    'User-Agent' = 'Mozilla/5.0 (compatible; CodexPaperLibrary/1.0; scholarly download)'
    'Accept' = 'application/pdf,application/octet-stream;q=0.9,*/*;q=0.1'
}

function Test-PdfFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    if ((Get-Item -LiteralPath $path).Length -lt 10000) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    return ($bytes.Length -ge 4 -and $bytes[0] -eq 0x25 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x44 -and $bytes[3] -eq 0x46)
}

$results = foreach ($item in $items) {
    $dir = if ($item.Tier -eq 'A') { Join-Path $papersRoot 'A_core' } else { Join-Path $papersRoot ("B_topic\" + $item.Topic) }
    $target = Join-Path $dir $item.File
    $status = 'existing'
    $errorText = ''
    if (-not (Test-PdfFile $target)) {
        $part = "$target.part"
        if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
        $status = 'failed'
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Invoke-WebRequest -Uri $item.Url -Headers $headers -OutFile $part -MaximumRedirection 8 -TimeoutSec 120
                if (-not (Test-PdfFile $part)) { throw 'Downloaded content is not a valid PDF.' }
                Move-Item -LiteralPath $part -Destination $target -Force
                $status = 'downloaded'
                $errorText = ''
                break
            } catch {
                $errorText = $_.Exception.Message
                if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
                Start-Sleep -Seconds (2 * $attempt)
            }
        }
    }
    [pscustomobject]@{
        id = $item.Id
        status = $status
        bytes = if (Test-Path -LiteralPath $target) { (Get-Item -LiteralPath $target).Length } else { 0 }
        local_pdf = if (Test-Path -LiteralPath $target) { [System.IO.Path]::GetRelativePath($workspace, $target).Replace('\','/') } else { '' }
        pdf_url = $item.Url
        error = $errorText
    }
}

$results | ConvertTo-Json -Depth 4
if (($results | Where-Object status -eq 'failed').Count -gt 0) { exit 2 }
