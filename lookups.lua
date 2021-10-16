local lookups = {}

lookups.r = {}
lookups.r[0] = "B"
lookups.r[1] = "C"
lookups.r[2] = "D"
lookups.r[3] = "E"
lookups.r[4] = "H"
lookups.r[5] = "L"
lookups.r[6] = "(HL)"
lookups.r[7] = "A"

lookups.rp = {}
lookups.rp[0] = "BC"
lookups.rp[1] = "DE"
lookups.rp[2] = "HL"
lookups.rp[3] = "SP"

lookups.rp2 = {}
lookups.rp2[0] = "BC"
lookups.rp2[1] = "DE"
lookups.rp2[2] = "HL"
lookups.rp2[3] = "AF"

lookups.cc = {}
lookups.cc[0] = regs.get_NZF
lookups.cc[1] = regs.get_ZF
lookups.cc[2] = regs.get_NCF
lookups.cc[3] = regs.get_CF

lookups.alu = {}
lookups.alu[0] = "ADD A"
lookups.alu[1] = "ADC A"
lookups.alu[2] = "SUB"
lookups.alu[3] = "SBC A"
lookups.alu[4] = "AND"
lookups.alu[5] = "XOR"
lookups.alu[6] = "OR"
lookups.alu[7] = "CP"

lookups.rot = {}
lookups.rot[0] = "RLC"
lookups.rot[1] = "RRC"
lookups.rot[2] = "RL"
lookups.rot[3] = "RR"
lookups.rot[4] = "SLA"
lookups.rot[5] = "SRA"
lookups.rot[6] = "SWAP"
lookups.rot[7] = "SRL"

return lookups
