NUM_REGS = 32


def generate_sv_enum(num_regs):
    # lines = []
    # lines.append("typedef enum logic [5:0] {")  # 6 bits needed for 64 regs

    # for i in range(num_regs):
    #     comma = "," if i < num_regs - 1 else ""
    #     lines.append(f"    P{i} = 6'd{i}{comma}")

    # lines.append("} phys_reg_e;")

    # return "\n".join(lines)

    lines = []
    lines.append("typedef enum logic [4:0] {")  # 6 bits needed for 64 regs

    for i in range(num_regs):
        comma = "," if i < num_regs - 1 else ""
        lines.append(f"    x{i} = 5'd{i}{comma}")

    lines.append("} logical_reg_t;")

    return "\n".join(lines)


if __name__ == "__main__":
    print(generate_sv_enum(NUM_REGS))
