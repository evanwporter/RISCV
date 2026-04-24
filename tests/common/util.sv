package testbench_utils_pkg;
  function string get_dirname(input string filepath);
    int i;
    for (i = filepath.len() - 1; i >= 0; i--) begin
      if (filepath[i] == "/" || filepath[i] == "\\") begin
        return filepath.substr(0, i - 1);
      end
    end
    return ".";  // fallback if no path
  endfunction
endpackage : testbench_utils_pkg
