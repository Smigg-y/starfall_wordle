--@name wordle/v2/wordle
--@author Smiggy
--@shared

--@include wordle/v2/sv_wordle.lua
--@include wordle/v2/cl_wordle.lua

if SERVER then
	require("wordle/v2/sv_wordle.lua")
else
	require("wordle/v2/cl_wordle.lua")
end
