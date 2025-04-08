from pynvml import *
nvmlInit()

# This sets the GPU to adjust - if this gives you errors or you have multiple GPUs, set to 1 or try other values.
myGPU = nvmlDeviceGetHandleByIndex(0)

# The GPU frequency offset value should replace the "80" in the line below.
#nvmlDeviceSetGpcClkVfOffset(myGPU, 1000)

# The Mem frequency Offset should be **multiplied by 2** to replace the "2500" below
# for example, an offset of 500 in GWE means inserting a value of 1000 in the next line
# I personally didn't overclock my memory 

#nvmlDeviceSetMemClkVfOffset(myGPU, 2500)

# The power limit should be set below in mW - 400W becomes 400000, etc. May not work for laptops. Remove the below line if you don't want to adjust power limits.
nvmlDeviceSetPowerManagementLimit(myGPU, 400000)