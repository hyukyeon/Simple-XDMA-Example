# XDMAC (Extended Direct Memory Access Controller)

고성능 SoC 시스템을 위한 4채널 멀티태스킹 DMA 컨트롤러 설계 프로젝트입니다. AMBA 3.0 APB Slave 인터페이스를 통한 설정과 128-bit AXI Master 인터페이스를 통한 고속 데이터 전송을 지원합니다.

## 주요 기능 (Features)

1.  **Multi-Channel & Fixed Priority:**
    *   4개의 독립된 채널 (CH0 ~ CH3) 지원.
    *   고정 우선순위(Fixed Priority) 방식의 중재기(Arbiter) 내장 (CH3 > CH2 > CH1 > CH0).
    *   **Preemption:** 낮은 우선순위 채널이 전송 중일 때 높은 우선순위 요청이 오면 버스트 단위로 즉시 양보 및 재개.

2.  **Scatter-Gather (Descriptor 기반 전송):**
    *   메모리에 저장된 Descriptor 리스트(`SRC`, `DST`, `LEN`, `NEXT`)를 자동으로 읽어와 전송 수행.
    *   CPU 개입 최소화.

3.  **Hardware Handshaking:**
    *   소프트웨어 트리거뿐만 아니라 외부 주변장치의 하드웨어 요청 신호(`i_hw_req`)를 통한 전송 지원.

4.  **AXI Burst Support:**
    *   128-bit 데이터 폭 지원 및 효율적인 버스트 전송.

## 파일 구조 (Project Structure)

```text
.
├── src/
│   ├── xdmac_top.v        # 최상위 통합 모듈 및 중재자(Arbiter)
│   ├── xdmac_axi_master.v # 공용 AXI Master 엔진 (Worker)
│   └── xdmac_apb_slave.v  # 레지스터 설정 인터페이스 (APB)
├── tb/
│   └── tb_xdmac.v         # Preemption 및 Scatter-Gather 시나리오 테스트벤치
├── run_sim.sh             # 시뮬레이션 자동화 스크립트
└── README.md              # 프로젝트 설명 문서
```

## 명명 규칙 (Naming Convention)

*   `i_`: Input Port
*   `o_`: Output Port
*   `r_`: Register (Flip-Flop)
*   `w_`: Internal Wire
*   `S_` / `CH_`: State Machine Constant

## 시뮬레이션 실행 방법 (How to Run)

Icarus Verilog와 GTKWave가 설치되어 있어야 합니다.

```bash
# 시뮬레이션 실행 (컴파일 + 실행 + 로그 생성)
./run_sim.sh

# 파형 확인
gtkwave xdmac.vcd
```

## 테스트 시나리오 설명

테스트벤치(`tb_xdmac.v`)는 다음과 같은 고난도 시나리오를 수행합니다:
1.  **CH0 시작:** 낮은 우선순위 채널이 긴 전송(64바이트)을 시작합니다.
2.  **CH3 가로채기:** 전송 도중 하드웨어 요청으로 CH3(최고 우선순위)이 Scatter-Gather 모드로 동작합니다.
3.  **복귀:** CH3 전송이 완료되면 CH0이 멈췄던 주소부터 다시 전송을 이어서 완료합니다.
