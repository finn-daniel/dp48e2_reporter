
module dsp_test_fixture (
  input  wire               clk,
  input  wire               clk_en,
  input  wire signed [25:0] a, d,
  input  wire signed [17:0] b,
  input  wire signed [25:0] c,
  output reg  signed [46:0] p
);

reg signed [25:0] a_reg = 0, d_reg = 0;
reg signed [17:0] b_reg = 0;
reg signed [25:0] c_reg_0 = 0;
reg signed [25:0] c_reg_1 = 0;
reg signed [26:0] preadd = 0;
reg signed [44:0] mult = 0;

always @(posedge clk) begin

  if (clk_en) begin

    a_reg <= a;
    b_reg <= b;

		c_reg_0 <= c;
		c_reg_1 <= c_reg_0;

    d_reg <= d;

		preadd <= d_reg + a_reg;

    mult <=  preadd * b_reg;

		p <= mult + c_reg_1;

  end
end

endmodule