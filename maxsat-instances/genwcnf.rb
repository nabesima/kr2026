#!/usr/bin/env ruby
require 'optparse'

#
# Command Line Arguments Analysis
#
$length = nil
$outdir = nil
$prg    = "bms_solver.py"
opt = OptionParser.new
opt.banner += " raw-file\n"
opt.banner += "  Generate wcnf file from the specified input"
opt.summary_width  = 8
opt.summary_indent = ' '*4
opt.on('-l LEN', "prefix length")  {|v| $length = v }
opt.on('-o DIR', "output dir")     {|v| $outdir = v }
opt.on('-p PRG', "solver program") {|v| $prg = v }
opt.parse!(ARGV)

if ARGV.size != 1 or $length == nil or $outdir == nil
  print opt
  exit
end

$raw     = ARGV[0]
$outdir  = $outdir + "/" + $length
$outfile = File.basename($raw) + ".xz"
$workdir = "."

`mkdir -p #{$outdir}`
cmd = "cd #{$workdir}; python3 #{$prg} --file #{$raw} --prefix #{$length} --dump #{$outdir}/#{$outfile}"
puts cmd
`#{cmd}`
