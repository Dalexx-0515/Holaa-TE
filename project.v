
/*
 * Copyright (c) 2024 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 * Author: Uri Shaked
 */

`default_nettype none

parameter LOGO_SIZE = 128;
parameter DISPLAY_WIDTH = 640;
parameter DISPLAY_HEIGHT = 480;

`define COLOR_WHITE 3'd7

module tt_um_vga_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  wire hsync, vsync;
  reg [1:0] R, G, B;
  wire video_active;
  wire [9:0] pix_x, pix_y;

  wire cfg_tile  = ui_in[0];
  wire cfg_color = ui_in[1];

  assign uo_out = {
      hsync, B[0], G[0], R[0],
      vsync, B[1], G[1], R[1]
  };

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  wire _unused_ok = &{ena, ui_in[7:2], uio_in};

  reg [9:0] prev_y;

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  reg [9:0] logo_left;
  reg [9:0] logo_top;
  reg dir_x, dir_y;
  reg [2:0] color_index;

  wire [5:0] color;
  wire pixel_value;

  wire [9:0] x = pix_x - logo_left;
  wire [9:0] y = pix_y - logo_top;

  wire logo_pixels =
      cfg_tile || ((x[9:7] == 0) && (y[9:7] == 0));

  bitmap_rom rom1 (
      .x(x[6:0]),
      .y(y[6:0]),
      .pixel(pixel_value)
  );

  palette palette_inst (
      .color_index(color_index),
      .rrggbb(color)
  );

  // ----------------------------------------
  // ESTELA CIAN
  // ----------------------------------------

  // Desplazamiento de la copia según la dirección.
  wire [9:0] trail_left =
      dir_x ? logo_left - 10'd12
            : logo_left + 10'd12;

  wire [9:0] trail_top =
      dir_y ? logo_top - 10'd12
            : logo_top + 10'd12;

  wire [9:0] trail_x = pix_x - trail_left;
  wire [9:0] trail_y = pix_y - trail_top;

  wire trail_region =
      (trail_x[9:7] == 0) &&
      (trail_y[9:7] == 0);

  wire trail_pixel;

  bitmap_rom rom_trail (
      .x(trail_x[6:0]),
      .y(trail_y[6:0]),
      .pixel(trail_pixel)
  );

  // Puntos decorativos del fondo.
  wire star_pixel =
      (pix_x[4:0] == 3  && pix_y[4:0] == 7)  ||
      (pix_x[4:0] == 17 && pix_y[4:0] == 23) ||
      (pix_x[4:0] == 27 && pix_y[4:0] == 13);

  // ----------------------------------------
  // VIDEO RGB
  // ----------------------------------------

  always @(posedge clk) begin
      if (!rst_n) begin
          R <= 0;
          G <= 0;
          B <= 0;
      end else begin
          R <= 0;
          G <= 0;
          B <= 0;

          if (video_active) begin

              // Logo principal: color de la paleta.
              if (logo_pixels && pixel_value) begin
                  R <= cfg_color ? color[5:4] : 2'b11;
                  G <= cfg_color ? color[3:2] : 2'b11;
                  B <= cfg_color ? color[1:0] : 2'b11;
              end

              // Estela cian.
              else if (trail_region && trail_pixel) begin
                  R <= 2'b00;
                  G <= 2'b11;
                  B <= 2'b11;
              end

              // Fondo con puntos azulados.
              else if (star_pixel) begin
                  R <= 2'b00;
                  G <= 2'b01;
                  B <= 2'b10;
              end
          end
      end
  end

  // ----------------------------------------
  // MOVIMIENTO, REBOTE Y CAMBIO DE COLOR
  // ----------------------------------------

  // Límites considerando el tamaño del logo.
  localparam RIGHT_LIMIT = DISPLAY_WIDTH - LOGO_SIZE;
  localparam BOTTOM_LIMIT = DISPLAY_HEIGHT - LOGO_SIZE;

  always @(posedge clk) begin
      if (!rst_n) begin
          logo_left   <= 200;
          logo_top    <= 200;
          dir_x       <= 1'b1;
          dir_y       <= 1'b0;
          color_index <= 3'd0;
          prev_y      <= 10'd0;
      end else begin
          prev_y <= pix_y;

          // Actualizar una vez por cuadro VGA.
          if ((pix_y == 0) && (prev_y != 0)) begin

              // Movimiento horizontal: 2 píxeles por cuadro.
              if (dir_x) begin
                  if (logo_left + 10'd2 >= RIGHT_LIMIT) begin
                      logo_left <= RIGHT_LIMIT;
                      dir_x <= 1'b0;
                      color_index <= color_index + 3'd1;
                  end else begin
                      logo_left <= logo_left + 10'd2;
                  end
              end else begin
                  if (logo_left <= 10'd2) begin
                      logo_left <= 10'd0;
                      dir_x <= 1'b1;
                      color_index <= color_index + 3'd1;
                  end else begin
                      logo_left <= logo_left - 10'd2;
                  end
              end

              // Movimiento vertical: 2 píxeles por cuadro.
              if (dir_y) begin
                  if (logo_top + 10'd2 >= BOTTOM_LIMIT) begin
                      logo_top <= BOTTOM_LIMIT;
                      dir_y <= 1'b0;
                      color_index <= color_index + 3'd1;
                  end else begin
                      logo_top <= logo_top + 10'd2;
                  end
              end else begin
                  if (logo_top <= 10'd2) begin
                      logo_top <= 10'd0;
                      dir_y <= 1'b1;
                      color_index <= color_index + 3'd1;
                  end else begin
                      logo_top <= logo_top - 10'd2;
                  end
              end
          end
      end
  end

endmodule

