# Simple XDMA Subsystem with SRAM/DRAM Modeling

고성능 SoC 시스템을 위한 **4채널 멀티태스킹 XDMA(Extended DMA) 컨트롤러 및 메모리 서브시스템** 설계 프로젝트입니다.  
이 프로젝트는 실제 하드웨어의 특성을 반영하기 위해 **SRAM(저지연)**과 **DRAM(고지연)** 모델을 포함하는 메모리 서브시스템을 구축하였습니다.

---

## 🚀 주요 기능 (Features)

1.  **Multi-Channel & Fixed Priority:**
    *   4개의 독립된 채널(CH0~CH3)을 관리하며, 고정 우선순위(CH3 > CH2 > CH1 > CH0)를 적용합니다.
2.  **Memory Subsystem with Latency Modeling:**
    *   **SRAM (2개):** Latency 1의 빠른 응답 속도를 가진 메모리 모델.
    *   **DRAM (2개):** Latency 15~20의 높은 지연 시간을 가진 메모리 모델.
    *   **AXI Interconnect (1x4):** 주소 디코딩을 통해 1개의 XDMAC 마스터를 4개의 메모리 슬레이브로 라우팅합니다.
3.  **Scatter-Gather (SG) Engine:**
    *   메모리에 저장된 Descriptor(`{SRC, DST, LEN, NEXT}`)를 자동으로 로드하여 CPU 개입 없이 연속 전송을 수행합니다.
4.  **AXI4 128-bit Subsystem:**
    *   데이터 대역폭 극대화를 위해 128-bit 데이터 폭을 사용하며, 메모리 타입에 따른 가변 지연 시간에도 안정적인 전송을 보장합니다.

---

## 🏗 시스템 구조 (System Architecture)

```text
[ XDMAC Subsystem ]
      |
      |-- [ XDMAC Top ] (Arbiter & FSM)
      |      |-- [ APB Slave ] (Control Regs)
      |      |-- [ AXI Master ] (Bus Engine)
      |
      |-- [ AXI Interconnect 1x4 ] (Address Decoder)
             |
             |-- [ SRAM 0 ] (Addr: 0x0..., Latency: 1)
             |-- [ SRAM 1 ] (Addr: 0x1..., Latency: 1)
             |-- [ DRAM 0 ] (Addr: 0x2..., Latency: 15)
             |-- [ DRAM 1 ] (Addr: 0x3..., Latency: 20)
```

---

## 🔄 핵심 시나리오: Mixed Memory Transfers

서로 다른 물리 구현 타입(SRAM/DRAM) 간의 데이터 전송 및 동시 중재 동작을 검증합니다.

### 시뮬레이션 시나리오
*   **CH0:** SRAM 0 → DRAM 0 (저지연 → 고지연)
*   **CH1:** SRAM 1 → DRAM 1 (저지연 → 고지연)
*   **CH2:** DRAM 0 → SRAM 1 (고지연 → 저지연)
*   **CH3:** DRAM 1 → SRAM 0 (고지연 → 저지연)

**검증 포인트:**
*   DRAM의 높은 Latency 동안 XDMAC가 `READY/VALID` 핸드셰이크를 올바르게 유지하는지 확인.
*   4개 채널 동시 요청 시, 고정 우선순위에 따른 순차적 전송 완료 확인.

---

## 📂 파일 구조 (Project Structure)

*   `src/xdmac_subsystem.v`: **Top Wrapper**. DMA, Interconnect, Memory 통합.
*   `src/xdmac_top.v`: Arbiter 및 채널 상태 제어.
*   `src/axi_interconnect_1x4.v`: 주소 기반 1-to-4 라우터.
*   `src/axi_slave_mem.v`: **Latency 파라미터**를 지원하는 메모리 모델 (SRAM/DRAM 공용).
*   `src/xdmac_axi_master.v`: 공용 AXI 엔진.
*   `src/xdmac_apb_slave.v`: 레지스터 설정 인터페이스.
*   `tb/tb_xdmac.v`: 서브시스템 전체 검증용 테스트벤치.

---

## 🛠 실행 방법 (Usage)

```bash
# 1. 시뮬레이션 실행 (SystemVerilog 2012 지원 필요)
./run_sim.sh

# 2. 파형 분석
gtkwave xdmac.vcd
```

## 📝 시뮬레이션 로그 예시
```text
--- Configuring All Channels for Mixed Memory Transfers ---
--- Triggering All Channels Simultaneously ---
[LOG 0] [DMA_TOP] CH0 Started ...
[LOG 0] [DMA_TOP] Arbiter: Granting Bus to CH3 (우선순위 기반 중재)
... (지연 시간이 다른 메모리 간 데이터 이동) ...
--- Verification ---
CH0 Success!
CH1 Success!
CH2 Success!
CH3 Success!
```
