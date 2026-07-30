//===-- NDS32SysRegs.td - NDS32 system registers -----------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// GENERATED FILE -- do not hand-edit. Regenerate with
// llvm/utils/NDS32/gen-sysregs.py, verify with verify-sysregs.py.
//
// Derived entirely by probing the GNU nds32be-elf toolchain: canonical
// names are whatever nds32be-elf-objdump prints for each architecturally
// distinct SRIDX, and aliases are the numeric spellings nds32be-elf-as
// accepts. Tool output only -- no GPL source is read and no encoding
// macro is reimplemented.

class NDS32SR<string n, bits<15> idx> : Register<n> {
  let Namespace = "NDS32";
  let HWEncoding{14-0} = idx;
}

// Canonical spellings. Listed FIRST in the SR class below because
// NDS32Disassembler's DecodeSRRegisterClass returns the first member
// matching an SRIDX -- so these, not the aliases, are what a decoded
// mfsr/mtsr prints.
def SR_CPU_VER : NDS32SR<"$cpu_ver", 0>;
def SR_CORE_ID : NDS32SR<"$core_id", 32>;
def SR_ICM_CFG : NDS32SR<"$icm_cfg", 256>;
def SR_DCM_CFG : NDS32SR<"$dcm_cfg", 512>;
def SR_MMU_CFG : NDS32SR<"$mmu_cfg", 768>;
def SR_MSC_CFG : NDS32SR<"$msc_cfg", 1024>;
def SR_MSC_CFG2 : NDS32SR<"$msc_cfg2", 1056>;
def SR_FUCOP_EXIST : NDS32SR<"$fucop_exist", 1280>;
def SR_PSW : NDS32SR<"$psw", 4096>;
def SR_IPSW : NDS32SR<"$ipsw", 4128>;
def SR_P_IPSW : NDS32SR<"$p_ipsw", 4160>;
def SR_IVB : NDS32SR<"$ivb", 4384>;
def SR_INT_CTRL : NDS32SR<"$int_ctrl", 4416>;
def SR_INT_GPR_PUSH_DIS : NDS32SR<"$int_gpr_push_dis", 4448>;
def SR_EVA : NDS32SR<"$eva", 4640>;
def SR_P_EVA : NDS32SR<"$p_eva", 4672>;
def SR_ITYPE : NDS32SR<"$itype", 4896>;
def SR_P_ITYPE : NDS32SR<"$p_itype", 4928>;
def SR_MERR : NDS32SR<"$merr", 5152>;
def SR_IPC : NDS32SR<"$ipc", 5408>;
def SR_P_IPC : NDS32SR<"$p_ipc", 5440>;
def SR_OIPC : NDS32SR<"$oipc", 5472>;
def SR_P_P0 : NDS32SR<"$p_p0", 5696>;
def SR_P_P1 : NDS32SR<"$p_p1", 5952>;
def SR_INT_MASK : NDS32SR<"$int_mask", 6144>;
def SR_INT_MASK2 : NDS32SR<"$int_mask2", 6176>;
def SR_INT_MASK3 : NDS32SR<"$int_mask3", 6208>;
def SR_INT_PEND : NDS32SR<"$int_pend", 6400>;
def SR_INT_PEND2 : NDS32SR<"$int_pend2", 6432>;
def SR_INT_PEND3 : NDS32SR<"$int_pend3", 6464>;
def SR_INT_TRIGGER : NDS32SR<"$int_trigger", 6528>;
def SR_INT_TRIGGER2 : NDS32SR<"$int_trigger2", 6560>;
def SR_SP_USR : NDS32SR<"$sp_usr", 6656>;
def SR_SP_PRIV : NDS32SR<"$sp_priv", 6688>;
def SR_SP_USR1 : NDS32SR<"$sp_usr1", 6720>;
def SR_SP_PRIV1 : NDS32SR<"$sp_priv1", 6752>;
def SR_SP_USR2 : NDS32SR<"$sp_usr2", 6784>;
def SR_SP_PRIV2 : NDS32SR<"$sp_priv2", 6816>;
def SR_SP_USR3 : NDS32SR<"$sp_usr3", 6848>;
def SR_SP_PRIV3 : NDS32SR<"$sp_priv3", 6880>;
def SR_INT_PRI : NDS32SR<"$int_pri", 6912>;
def SR_INT_PRI2 : NDS32SR<"$int_pri2", 6944>;
def SR_INT_PRI3 : NDS32SR<"$int_pri3", 6976>;
def SR_INT_PRI4 : NDS32SR<"$int_pri4", 7008>;
def SR_MMU_CTL : NDS32SR<"$mmu_ctl", 8192>;
def SR_BG_REGION : NDS32SR<"$bg_region", 8224>;
def SR_L1_PPTB : NDS32SR<"$l1_pptb", 8448>;
def SR_TLB_VPN : NDS32SR<"$tlb_vpn", 8704>;
def SR_TLB_DATA : NDS32SR<"$tlb_data", 8960>;
def SR_TLB_MISC : NDS32SR<"$tlb_misc", 9216>;
def SR_VLPT_IDX : NDS32SR<"$vlpt_idx", 9472>;
def SR_ILMB : NDS32SR<"$ilmb", 9728>;
def SR_DLMB : NDS32SR<"$dlmb", 9984>;
def SR_CACHE_CTL : NDS32SR<"$cache_ctl", 10240>;
def SR_HSMP_SADDR : NDS32SR<"$hsmp_saddr", 10496>;
def SR_HSMP_EADDR : NDS32SR<"$hsmp_eaddr", 10528>;
def SR_SDZ_CTL : NDS32SR<"$sdz_ctl", 12032>;
def SR_MISC_CTL : NDS32SR<"$misc_ctl", 12064>;
def SR_ECC_MISC : NDS32SR<"$ecc_misc", 12096>;
def SR_BPC0 : NDS32SR<"$bpc0", 12288>;
def SR_BPC1 : NDS32SR<"$bpc1", 12320>;
def SR_BPC2 : NDS32SR<"$bpc2", 12352>;
def SR_BPC3 : NDS32SR<"$bpc3", 12384>;
def SR_BPC4 : NDS32SR<"$bpc4", 12416>;
def SR_BPC5 : NDS32SR<"$bpc5", 12448>;
def SR_BPC6 : NDS32SR<"$bpc6", 12480>;
def SR_BPC7 : NDS32SR<"$bpc7", 12512>;
def SR_BPA0 : NDS32SR<"$bpa0", 12544>;
def SR_BPA1 : NDS32SR<"$bpa1", 12576>;
def SR_BPA2 : NDS32SR<"$bpa2", 12608>;
def SR_BPA3 : NDS32SR<"$bpa3", 12640>;
def SR_BPA4 : NDS32SR<"$bpa4", 12672>;
def SR_BPA5 : NDS32SR<"$bpa5", 12704>;
def SR_BPA6 : NDS32SR<"$bpa6", 12736>;
def SR_BPA7 : NDS32SR<"$bpa7", 12768>;
def SR_BPAM0 : NDS32SR<"$bpam0", 12800>;
def SR_BPAM1 : NDS32SR<"$bpam1", 12832>;
def SR_BPAM2 : NDS32SR<"$bpam2", 12864>;
def SR_BPAM3 : NDS32SR<"$bpam3", 12896>;
def SR_BPAM4 : NDS32SR<"$bpam4", 12928>;
def SR_BPAM5 : NDS32SR<"$bpam5", 12960>;
def SR_BPAM6 : NDS32SR<"$bpam6", 12992>;
def SR_BPAM7 : NDS32SR<"$bpam7", 13024>;
def SR_BPV0 : NDS32SR<"$bpv0", 13056>;
def SR_BPV1 : NDS32SR<"$bpv1", 13088>;
def SR_BPV2 : NDS32SR<"$bpv2", 13120>;
def SR_BPV3 : NDS32SR<"$bpv3", 13152>;
def SR_BPV4 : NDS32SR<"$bpv4", 13184>;
def SR_BPV5 : NDS32SR<"$bpv5", 13216>;
def SR_BPV6 : NDS32SR<"$bpv6", 13248>;
def SR_BPV7 : NDS32SR<"$bpv7", 13280>;
def SR_BPCID0 : NDS32SR<"$bpcid0", 13312>;
def SR_BPCID1 : NDS32SR<"$bpcid1", 13344>;
def SR_BPCID2 : NDS32SR<"$bpcid2", 13376>;
def SR_BPCID3 : NDS32SR<"$bpcid3", 13408>;
def SR_BPCID4 : NDS32SR<"$bpcid4", 13440>;
def SR_BPCID5 : NDS32SR<"$bpcid5", 13472>;
def SR_BPCID6 : NDS32SR<"$bpcid6", 13504>;
def SR_BPCID7 : NDS32SR<"$bpcid7", 13536>;
def SR_EDM_CFG : NDS32SR<"$edm_cfg", 13568>;
def SR_EDMSW : NDS32SR<"$edmsw", 13824>;
def SR_EDM_CTL : NDS32SR<"$edm_ctl", 14080>;
def SR_EDM_DTR : NDS32SR<"$edm_dtr", 14336>;
def SR_BPMTC : NDS32SR<"$bpmtc", 14592>;
def SR_DIMBR : NDS32SR<"$dimbr", 14848>;
def SR_TECR0 : NDS32SR<"$tecr0", 15872>;
def SR_TECR1 : NDS32SR<"$tecr1", 15904>;
def SR_PFMC0 : NDS32SR<"$pfmc0", 16384>;
def SR_PFMC1 : NDS32SR<"$pfmc1", 16416>;
def SR_PFMC2 : NDS32SR<"$pfmc2", 16448>;
def SR_PFM_CTL : NDS32SR<"$pfm_ctl", 16640>;
def SR_PFT_CTL : NDS32SR<"$pft_ctl", 16896>;
def SR_PRUSR_ACC_CTL : NDS32SR<"$prusr_acc_ctl", 17408>;
def SR_FUCPR : NDS32SR<"$fucpr", 17664>;
def SR_HSP_CTL : NDS32SR<"$hsp_ctl", 17920>;
def SR_SP_BOUND : NDS32SR<"$sp_bound", 17952>;
def SR_SP_BOUND_PRIV : NDS32SR<"$sp_bound_priv", 17984>;
def SR_SP_BASE : NDS32SR<"$sp_base", 18016>;
def SR_SP_BASE_PRIV : NDS32SR<"$sp_base_priv", 18048>;
def SR_DMA_CFG : NDS32SR<"$dma_cfg", 20480>;
def SR_DMA_GCSW : NDS32SR<"$dma_gcsw", 20736>;
def SR_DMA_CHNSEL : NDS32SR<"$dma_chnsel", 20992>;
def SR_DMA_ACT : NDS32SR<"$dma_act", 21248>;
def SR_DMA_SETUP : NDS32SR<"$dma_setup", 21504>;
def SR_DMA_ISADDR : NDS32SR<"$dma_isaddr", 21760>;
def SR_DMA_ESADDR : NDS32SR<"$dma_esaddr", 22016>;
def SR_DMA_TCNT : NDS32SR<"$dma_tcnt", 22272>;
def SR_DMA_RCNT : NDS32SR<"$dma_rcnt", 22304>;
def SR_DMA_STATUS : NDS32SR<"$dma_status", 22528>;
def SR_DMA_HSTATUS : NDS32SR<"$dma_hstatus", 22560>;
def SR_DMA_2DSET : NDS32SR<"$dma_2dset", 22784>;
def SR_DMA_2DSCTL : NDS32SR<"$dma_2dsctl", 22816>;
def SR_SECUR0 : NDS32SR<"$secur0", 24576>;
def SR_SECUR1 : NDS32SR<"$secur1", 24832>;
def SR_SECUR2 : NDS32SR<"$secur2", 24864>;
def SR_SECUR3 : NDS32SR<"$secur3", 24896>;

// Alias spellings the GNU assembler also accepts (the numeric $crN/$irN/
// $drN forms). Separate defs sharing the canonical register's SRIDX: the
// asm parser resolves a name via the generated MatchRegisterName, so an
// alias must be a register in its own right to be accepted.
def SR_CR0 : NDS32SR<"$cr0", 0>;   // == $cpu_ver
def SR_CR5 : NDS32SR<"$cr5", 32>;   // == $core_id
def SR_CR1 : NDS32SR<"$cr1", 256>;   // == $icm_cfg
def SR_CR2 : NDS32SR<"$cr2", 512>;   // == $dcm_cfg
def SR_CR3 : NDS32SR<"$cr3", 768>;   // == $mmu_cfg
def SR_CR4 : NDS32SR<"$cr4", 1024>;   // == $msc_cfg
def SR_CR7 : NDS32SR<"$cr7", 1056>;   // == $msc_cfg2
def SR_CR6 : NDS32SR<"$cr6", 1280>;   // == $fucop_exist
def SR_IR0 : NDS32SR<"$ir0", 4096>;   // == $psw
def SR_IR1 : NDS32SR<"$ir1", 4128>;   // == $ipsw
def SR_IR2 : NDS32SR<"$ir2", 4160>;   // == $p_ipsw
def SR_IR3 : NDS32SR<"$ir3", 4384>;   // == $ivb
def SR_IR19 : NDS32SR<"$ir19", 4416>;   // == $int_ctrl
def SR_IR30 : NDS32SR<"$ir30", 4448>;   // == $int_gpr_push_dis
def SR_IR4 : NDS32SR<"$ir4", 4640>;   // == $eva
def SR_IR5 : NDS32SR<"$ir5", 4672>;   // == $p_eva
def SR_IR6 : NDS32SR<"$ir6", 4896>;   // == $itype
def SR_IR7 : NDS32SR<"$ir7", 4928>;   // == $p_itype
def SR_IR8 : NDS32SR<"$ir8", 5152>;   // == $merr
def SR_IR9 : NDS32SR<"$ir9", 5408>;   // == $ipc
def SR_IR10 : NDS32SR<"$ir10", 5440>;   // == $p_ipc
def SR_IR11 : NDS32SR<"$ir11", 5472>;   // == $oipc
def SR_IR12 : NDS32SR<"$ir12", 5696>;   // == $p_p0
def SR_IR13 : NDS32SR<"$ir13", 5952>;   // == $p_p1
def SR_IR14 : NDS32SR<"$ir14", 6144>;   // == $int_mask
def SR_IR26 : NDS32SR<"$ir26", 6176>;   // == $int_mask2
def SR_IR31 : NDS32SR<"$ir31", 6208>;   // == $int_mask3
def SR_IR15 : NDS32SR<"$ir15", 6400>;   // == $int_pend
def SR_IR27 : NDS32SR<"$ir27", 6432>;   // == $int_pend2
def SR_IR32 : NDS32SR<"$ir32", 6464>;   // == $int_pend3
def SR_IR29 : NDS32SR<"$ir29", 6528>;   // == $int_trigger
def SR_IR35 : NDS32SR<"$ir35", 6560>;   // == $int_trigger2
def SR_IR16 : NDS32SR<"$ir16", 6656>;   // == $sp_usr
def SR_IR17 : NDS32SR<"$ir17", 6688>;   // == $sp_priv
def SR_IR20 : NDS32SR<"$ir20", 6720>;   // == $sp_usr1
def SR_IR21 : NDS32SR<"$ir21", 6752>;   // == $sp_priv1
def SR_IR22 : NDS32SR<"$ir22", 6784>;   // == $sp_usr2
def SR_IR23 : NDS32SR<"$ir23", 6816>;   // == $sp_priv2
def SR_IR24 : NDS32SR<"$ir24", 6848>;   // == $sp_usr3
def SR_IR25 : NDS32SR<"$ir25", 6880>;   // == $sp_priv3
def SR_IR18 : NDS32SR<"$ir18", 6912>;   // == $int_pri
def SR_IR28 : NDS32SR<"$ir28", 6944>;   // == $int_pri2
def SR_IR33 : NDS32SR<"$ir33", 6976>;   // == $int_pri3
def SR_IR34 : NDS32SR<"$ir34", 7008>;   // == $int_pri4
def SR_MR0 : NDS32SR<"$mr0", 8192>;   // == $mmu_ctl
def SR_MR11 : NDS32SR<"$mr11", 8224>;   // == $bg_region
def SR_MR1 : NDS32SR<"$mr1", 8448>;   // == $l1_pptb
def SR_MR2 : NDS32SR<"$mr2", 8704>;   // == $tlb_vpn
def SR_MR3 : NDS32SR<"$mr3", 8960>;   // == $tlb_data
def SR_MR4 : NDS32SR<"$mr4", 9216>;   // == $tlb_misc
def SR_MR5 : NDS32SR<"$mr5", 9472>;   // == $vlpt_idx
def SR_MR6 : NDS32SR<"$mr6", 9728>;   // == $ilmb
def SR_MR7 : NDS32SR<"$mr7", 9984>;   // == $dlmb
def SR_MR8 : NDS32SR<"$mr8", 10240>;   // == $cache_ctl
def SR_MR9 : NDS32SR<"$mr9", 10496>;   // == $hsmp_saddr
def SR_MR10 : NDS32SR<"$mr10", 10528>;   // == $hsmp_eaddr
def SR_IDR0 : NDS32SR<"$idr0", 12032>;   // == $sdz_ctl
def SR_IDR1 : NDS32SR<"$idr1", 12064>;   // == $misc_ctl
def SR_IDR2 : NDS32SR<"$idr2", 12096>;   // == $ecc_misc
def SR_DR0 : NDS32SR<"$dr0", 12288>;   // == $bpc0
def SR_DR5 : NDS32SR<"$dr5", 12320>;   // == $bpc1
def SR_DR10 : NDS32SR<"$dr10", 12352>;   // == $bpc2
def SR_DR15 : NDS32SR<"$dr15", 12384>;   // == $bpc3
def SR_DR20 : NDS32SR<"$dr20", 12416>;   // == $bpc4
def SR_DR25 : NDS32SR<"$dr25", 12448>;   // == $bpc5
def SR_DR30 : NDS32SR<"$dr30", 12480>;   // == $bpc6
def SR_DR35 : NDS32SR<"$dr35", 12512>;   // == $bpc7
def SR_DR1 : NDS32SR<"$dr1", 12544>;   // == $bpa0
def SR_DR6 : NDS32SR<"$dr6", 12576>;   // == $bpa1
def SR_DR11 : NDS32SR<"$dr11", 12608>;   // == $bpa2
def SR_DR16 : NDS32SR<"$dr16", 12640>;   // == $bpa3
def SR_DR21 : NDS32SR<"$dr21", 12672>;   // == $bpa4
def SR_DR26 : NDS32SR<"$dr26", 12704>;   // == $bpa5
def SR_DR31 : NDS32SR<"$dr31", 12736>;   // == $bpa6
def SR_DR36 : NDS32SR<"$dr36", 12768>;   // == $bpa7
def SR_DR2 : NDS32SR<"$dr2", 12800>;   // == $bpam0
def SR_DR7 : NDS32SR<"$dr7", 12832>;   // == $bpam1
def SR_DR12 : NDS32SR<"$dr12", 12864>;   // == $bpam2
def SR_DR17 : NDS32SR<"$dr17", 12896>;   // == $bpam3
def SR_DR22 : NDS32SR<"$dr22", 12928>;   // == $bpam4
def SR_DR27 : NDS32SR<"$dr27", 12960>;   // == $bpam5
def SR_DR32 : NDS32SR<"$dr32", 12992>;   // == $bpam6
def SR_DR37 : NDS32SR<"$dr37", 13024>;   // == $bpam7
def SR_DR3 : NDS32SR<"$dr3", 13056>;   // == $bpv0
def SR_DR8 : NDS32SR<"$dr8", 13088>;   // == $bpv1
def SR_DR13 : NDS32SR<"$dr13", 13120>;   // == $bpv2
def SR_DR18 : NDS32SR<"$dr18", 13152>;   // == $bpv3
def SR_DR23 : NDS32SR<"$dr23", 13184>;   // == $bpv4
def SR_DR28 : NDS32SR<"$dr28", 13216>;   // == $bpv5
def SR_DR33 : NDS32SR<"$dr33", 13248>;   // == $bpv6
def SR_DR38 : NDS32SR<"$dr38", 13280>;   // == $bpv7
def SR_DR4 : NDS32SR<"$dr4", 13312>;   // == $bpcid0
def SR_DR9 : NDS32SR<"$dr9", 13344>;   // == $bpcid1
def SR_DR14 : NDS32SR<"$dr14", 13376>;   // == $bpcid2
def SR_DR19 : NDS32SR<"$dr19", 13408>;   // == $bpcid3
def SR_DR24 : NDS32SR<"$dr24", 13440>;   // == $bpcid4
def SR_DR29 : NDS32SR<"$dr29", 13472>;   // == $bpcid5
def SR_DR34 : NDS32SR<"$dr34", 13504>;   // == $bpcid6
def SR_DR39 : NDS32SR<"$dr39", 13536>;   // == $bpcid7
def SR_DR40 : NDS32SR<"$dr40", 13568>;   // == $edm_cfg
def SR_DR41 : NDS32SR<"$dr41", 13824>;   // == $edmsw
def SR_DR42 : NDS32SR<"$dr42", 14080>;   // == $edm_ctl
def SR_DR43 : NDS32SR<"$dr43", 14336>;   // == $edm_dtr
def SR_DR44 : NDS32SR<"$dr44", 14592>;   // == $bpmtc
def SR_DR45 : NDS32SR<"$dr45", 14848>;   // == $dimbr
def SR_DR46 : NDS32SR<"$dr46", 15872>;   // == $tecr0
def SR_DR47 : NDS32SR<"$dr47", 15904>;   // == $tecr1
def SR_PFR0 : NDS32SR<"$pfr0", 16384>;   // == $pfmc0
def SR_PFR1 : NDS32SR<"$pfr1", 16416>;   // == $pfmc1
def SR_PFR2 : NDS32SR<"$pfr2", 16448>;   // == $pfmc2
def SR_PFR3 : NDS32SR<"$pfr3", 16640>;   // == $pfm_ctl
def SR_PFR4 : NDS32SR<"$pfr4", 16896>;   // == $pft_ctl
def SR_HSPR0 : NDS32SR<"$hspr0", 17920>;   // == $hsp_ctl
def SR_HSPR1 : NDS32SR<"$hspr1", 17952>;   // == $sp_bound
def SR_HSPR2 : NDS32SR<"$hspr2", 17984>;   // == $sp_bound_priv
def SR_HSPR3 : NDS32SR<"$hspr3", 18016>;   // == $sp_base
def SR_HSPR4 : NDS32SR<"$hspr4", 18048>;   // == $sp_base_priv
def SR_DMAR0 : NDS32SR<"$dmar0", 20480>;   // == $dma_cfg
def SR_DMAR1 : NDS32SR<"$dmar1", 20736>;   // == $dma_gcsw
def SR_DMAR2 : NDS32SR<"$dmar2", 20992>;   // == $dma_chnsel
def SR_DMAR3 : NDS32SR<"$dmar3", 21248>;   // == $dma_act
def SR_DMAR4 : NDS32SR<"$dmar4", 21504>;   // == $dma_setup
def SR_DMAR5 : NDS32SR<"$dmar5", 21760>;   // == $dma_isaddr
def SR_DMAR6 : NDS32SR<"$dmar6", 22016>;   // == $dma_esaddr
def SR_DMAR7 : NDS32SR<"$dmar7", 22272>;   // == $dma_tcnt
def SR_DMAR11 : NDS32SR<"$dmar11", 22304>;   // == $dma_rcnt
def SR_DMAR8 : NDS32SR<"$dmar8", 22528>;   // == $dma_status
def SR_DMAR12 : NDS32SR<"$dmar12", 22560>;   // == $dma_hstatus
def SR_DMAR9 : NDS32SR<"$dmar9", 22784>;   // == $dma_2dset
def SR_DMAR10 : NDS32SR<"$dmar10", 22816>;   // == $dma_2dsctl

// Not allocatable: these are named operands of mfsr/mtsr only.
def SR : RegisterClass<"NDS32", [i32], 32, (add
  SR_CPU_VER, SR_CORE_ID, SR_ICM_CFG, SR_DCM_CFG, SR_MMU_CFG, SR_MSC_CFG,
  SR_MSC_CFG2, SR_FUCOP_EXIST, SR_PSW, SR_IPSW, SR_P_IPSW, SR_IVB,
  SR_INT_CTRL, SR_INT_GPR_PUSH_DIS, SR_EVA, SR_P_EVA, SR_ITYPE, SR_P_ITYPE,
  SR_MERR, SR_IPC, SR_P_IPC, SR_OIPC, SR_P_P0, SR_P_P1,
  SR_INT_MASK, SR_INT_MASK2, SR_INT_MASK3, SR_INT_PEND, SR_INT_PEND2, SR_INT_PEND3,
  SR_INT_TRIGGER, SR_INT_TRIGGER2, SR_SP_USR, SR_SP_PRIV, SR_SP_USR1, SR_SP_PRIV1,
  SR_SP_USR2, SR_SP_PRIV2, SR_SP_USR3, SR_SP_PRIV3, SR_INT_PRI, SR_INT_PRI2,
  SR_INT_PRI3, SR_INT_PRI4, SR_MMU_CTL, SR_BG_REGION, SR_L1_PPTB, SR_TLB_VPN,
  SR_TLB_DATA, SR_TLB_MISC, SR_VLPT_IDX, SR_ILMB, SR_DLMB, SR_CACHE_CTL,
  SR_HSMP_SADDR, SR_HSMP_EADDR, SR_SDZ_CTL, SR_MISC_CTL, SR_ECC_MISC, SR_BPC0,
  SR_BPC1, SR_BPC2, SR_BPC3, SR_BPC4, SR_BPC5, SR_BPC6,
  SR_BPC7, SR_BPA0, SR_BPA1, SR_BPA2, SR_BPA3, SR_BPA4,
  SR_BPA5, SR_BPA6, SR_BPA7, SR_BPAM0, SR_BPAM1, SR_BPAM2,
  SR_BPAM3, SR_BPAM4, SR_BPAM5, SR_BPAM6, SR_BPAM7, SR_BPV0,
  SR_BPV1, SR_BPV2, SR_BPV3, SR_BPV4, SR_BPV5, SR_BPV6,
  SR_BPV7, SR_BPCID0, SR_BPCID1, SR_BPCID2, SR_BPCID3, SR_BPCID4,
  SR_BPCID5, SR_BPCID6, SR_BPCID7, SR_EDM_CFG, SR_EDMSW, SR_EDM_CTL,
  SR_EDM_DTR, SR_BPMTC, SR_DIMBR, SR_TECR0, SR_TECR1, SR_PFMC0,
  SR_PFMC1, SR_PFMC2, SR_PFM_CTL, SR_PFT_CTL, SR_PRUSR_ACC_CTL, SR_FUCPR,
  SR_HSP_CTL, SR_SP_BOUND, SR_SP_BOUND_PRIV, SR_SP_BASE, SR_SP_BASE_PRIV, SR_DMA_CFG,
  SR_DMA_GCSW, SR_DMA_CHNSEL, SR_DMA_ACT, SR_DMA_SETUP, SR_DMA_ISADDR, SR_DMA_ESADDR,
  SR_DMA_TCNT, SR_DMA_RCNT, SR_DMA_STATUS, SR_DMA_HSTATUS, SR_DMA_2DSET, SR_DMA_2DSCTL,
  SR_SECUR0, SR_SECUR1, SR_SECUR2, SR_SECUR3, SR_CR0, SR_CR5,
  SR_CR1, SR_CR2, SR_CR3, SR_CR4, SR_CR7, SR_CR6,
  SR_IR0, SR_IR1, SR_IR2, SR_IR3, SR_IR19, SR_IR30,
  SR_IR4, SR_IR5, SR_IR6, SR_IR7, SR_IR8, SR_IR9,
  SR_IR10, SR_IR11, SR_IR12, SR_IR13, SR_IR14, SR_IR26,
  SR_IR31, SR_IR15, SR_IR27, SR_IR32, SR_IR29, SR_IR35,
  SR_IR16, SR_IR17, SR_IR20, SR_IR21, SR_IR22, SR_IR23,
  SR_IR24, SR_IR25, SR_IR18, SR_IR28, SR_IR33, SR_IR34,
  SR_MR0, SR_MR11, SR_MR1, SR_MR2, SR_MR3, SR_MR4,
  SR_MR5, SR_MR6, SR_MR7, SR_MR8, SR_MR9, SR_MR10,
  SR_IDR0, SR_IDR1, SR_IDR2, SR_DR0, SR_DR5, SR_DR10,
  SR_DR15, SR_DR20, SR_DR25, SR_DR30, SR_DR35, SR_DR1,
  SR_DR6, SR_DR11, SR_DR16, SR_DR21, SR_DR26, SR_DR31,
  SR_DR36, SR_DR2, SR_DR7, SR_DR12, SR_DR17, SR_DR22,
  SR_DR27, SR_DR32, SR_DR37, SR_DR3, SR_DR8, SR_DR13,
  SR_DR18, SR_DR23, SR_DR28, SR_DR33, SR_DR38, SR_DR4,
  SR_DR9, SR_DR14, SR_DR19, SR_DR24, SR_DR29, SR_DR34,
  SR_DR39, SR_DR40, SR_DR41, SR_DR42, SR_DR43, SR_DR44,
  SR_DR45, SR_DR46, SR_DR47, SR_PFR0, SR_PFR1, SR_PFR2,
  SR_PFR3, SR_PFR4, SR_HSPR0, SR_HSPR1, SR_HSPR2, SR_HSPR3,
  SR_HSPR4, SR_DMAR0, SR_DMAR1, SR_DMAR2, SR_DMAR3, SR_DMAR4,
  SR_DMAR5, SR_DMAR6, SR_DMAR7, SR_DMAR11, SR_DMAR8, SR_DMAR12,
  SR_DMAR9, SR_DMAR10
)> {
  let isAllocatable = 0;
}
