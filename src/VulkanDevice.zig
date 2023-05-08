const std = @import("std");

const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
    @cDefine("GLFW_EXPOSE_NATIVE_WIN32", "1");
    @cDefine("GLFW_EXPOSE_NATIVE_WGL", "1");
    @cInclude("GLFW/glfw3native.h");
});

const vulkan = @cImport({
    @cInclude("vulkan/vulkan.h");
});

var instance: vulkan.VkInstance = undefined;
var surface: vulkan.VkSurfaceKHR = undefined;
var graphicsQueueIndex: u32 = 0;
var transferQueueIndex: u32 = 0;
var presentationQueueIndex: u32 = 0;

const VulkanErrors = error{Fatal};

fn findDevice(allocTemp: std.mem.Allocator) !vulkan.VkPhysicalDevice {
    var deviceCount: u32 = 0;
    var result = vulkan.vkEnumeratePhysicalDevices(instance, &deviceCount, null);
    if ((result != vulkan.VK_SUCCESS) or (deviceCount < 1)) {
        std.log.err("Couldn't find any vulkan devices\n", .{});
        return VulkanErrors.Fatal;
    }
    var physicalDevices = std.ArrayList(vulkan.VkPhysicalDevice).init(allocTemp);
    defer physicalDevices.deinit();
    try physicalDevices.resize(deviceCount);

    result = vulkan.vkEnumeratePhysicalDevices(instance, &deviceCount, physicalDevices.items.ptr);
    if (result != vulkan.VK_SUCCESS) {
        std.log.err("Couldn't find any vulkan devices\n", .{});
        return VulkanErrors.Fatal;
    }

    var foundDevice: ?usize = null;
    var physicalDeviceProps = std.ArrayList(vulkan.VkPhysicalDeviceProperties).init(allocTemp);
    defer physicalDeviceProps.deinit();
    try physicalDeviceProps.resize(deviceCount);

    for (physicalDevices.items) |device, devIndex| {
        vulkan.vkGetPhysicalDeviceProperties(device, &physicalDeviceProps.items[devIndex]);
    }

    // First try to find a discrete gpu.
    for (physicalDeviceProps.items) |prop, propIndex| {
        if (prop.deviceType ==
            vulkan.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
        {
            foundDevice = propIndex;
            break;
        }
    }

    // Next find an integrated GPU
    if (foundDevice == null) {
        for (physicalDeviceProps.items) |prop, propIndex| {
            if (prop.deviceType ==
                vulkan.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU)
            {
                foundDevice = propIndex;
                break;
            }
        }
    }

    // Not going to support any other types of GPU's.
    if (foundDevice == null) {
        std.log.err("Couldn't find a suitable vulkan device\n", .{});
        return VulkanErrors.Fatal;
    }

    const chosenProps: vulkan.VkPhysicalDeviceProperties = physicalDeviceProps.items[foundDevice.?];
    std.log.info("Found a Vulkan Device! Name: {s}", .{chosenProps.deviceName});
    if (chosenProps.apiVersion < vulkan.VK_API_VERSION_1_2) {
        std.log.err("equire Vulkan 1.2 or greater, check for newer drivers\n", .{});
        return VulkanErrors.Fatal;
    }

    //var memProps : vulkan.VkPhysicalDeviceMemoryProperties;
    //vulkan.vkGetPhysicalDeviceMemoryProperties(physicalDevices[foundDevice.?], &memProps);
    std.log.info("  Device max allocations: {}", .{chosenProps.limits.maxMemoryAllocationCount});
    std.log.info("  Device max array layers: {}", .{chosenProps.limits.maxImageArrayLayers});
    std.log.info("  Device max 2D image dimensions: {}", .{chosenProps.limits.maxImageDimension2D});
    std.log.info("  Device max multisample: {}", .{chosenProps.limits.framebufferColorSampleCounts});
    //for(0..memProps.memoryTypeCount) |i| {
    //	if(memProps.memoryTypes[i].propertyFlags & vulkan.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) {
    //		std.log.info("  Device Local Memory Amount: {}MB",
    //		       memProps.memoryHeaps[memProps.memoryTypes[i].heapIndex].size / (1024 * 1024));
    //	}
    //}

    var queueProps = std.ArrayList(vulkan.VkQueueFamilyProperties).init(allocTemp);
    defer queueProps.deinit();
    var numQueueProps: u32 = 0;
    vulkan.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevices.items[foundDevice.?], &numQueueProps, null);
    try queueProps.resize(numQueueProps);
    vulkan.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevices.items[foundDevice.?], &numQueueProps, queueProps.items.ptr);

    var graphicsQueues = try std.ArrayList(usize).initCapacity(allocTemp, queueProps.items.len);
    defer graphicsQueues.deinit();
    var transferQueues = try std.ArrayList(usize).initCapacity(allocTemp, queueProps.items.len);
    defer transferQueues.deinit();
    var presentationQueues = try std.ArrayList(usize).initCapacity(allocTemp, queueProps.items.len);
    defer presentationQueues.deinit();
    var dedicatedTransfer: ?usize = null;
    var graphicsAndPresentation: ?usize = null;
    var graphicsAndCompute: ?usize = null;
    for (queueProps.items) |queueProp, i| {
        var supportsGraphics = false;
        var supportsCompute = false;
        var supportsTransfer = false;
        var supportsPresentation = false;

        std.log.info("Queue family: {}\n", .{i});
        // This one should only be false for tesla compute cards and similiar
        if ((queueProp.queueFlags & vulkan.VK_QUEUE_GRAPHICS_BIT) != 0 and queueProp.queueCount >= 1) {
            supportsGraphics = true;
            try graphicsQueues.append(i);
            std.log.info("  supports graphics\n", .{});
        }
        if ((queueProp.queueFlags & vulkan.VK_QUEUE_COMPUTE_BIT) != 0 and queueProp.queueCount >= 1) {
            supportsCompute = true;
            std.log.info("  supports compute\n", .{});
        }
        if ((queueProp.queueFlags & vulkan.VK_QUEUE_TRANSFER_BIT) != 0 and queueProp.queueCount >= 1) {
            supportsTransfer = true;
            try transferQueues.append(i);
            std.log.info("  supports transfer\n", .{});
        }

        var surfaceSupported: u32 = 0;
        _ = vulkan.vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevices.items[foundDevice.?], @intCast(u32, i), surface, &surfaceSupported);
        if (surfaceSupported != 0) {
            supportsPresentation = true;
            try presentationQueues.append(i);
            std.log.info("  supports presentation\n", .{});
        }

        // for transfers, prefer a dedicated transfer queue(. If more than one,
        // grab first
        if (!supportsGraphics and !supportsCompute and !supportsPresentation and supportsTransfer and
            dedicatedTransfer == null)
        {
            dedicatedTransfer = i;
        }
        // For graphics, we prefer one that does graphics, compute, and presentation
        if (supportsGraphics and supportsCompute and supportsPresentation and
            graphicsAndPresentation == null)
        {
            graphicsAndPresentation = i;
        }
        // We can handle seperate presentation though, but not seperatet graphics and compute at the moment.
        if (supportsGraphics and supportsCompute and graphicsAndCompute == null) {
            graphicsAndCompute = i;
        }
    }

    if (transferQueues.items.len == 0) {
        std.log.err("Could not find a valid vulkan transfer queue", .{});
        return VulkanErrors.Fatal;
    }

    if (presentationQueues.items.len == 0) {
        std.log.err("Could not find a valid vulkan presentation queue", .{});
        return VulkanErrors.Fatal;
    }

    if (graphicsAndCompute == null) {
        std.log.err("Could not find a valid vulkan graphics queue", .{});
        return VulkanErrors.Fatal;
    }

    transferQueueIndex = @intCast(u32, dedicatedTransfer orelse transferQueues.items[0]);
    presentationQueueIndex = @intCast(u32, graphicsAndPresentation orelse presentationQueues.items[0]);
    graphicsQueueIndex = @intCast(u32, graphicsAndPresentation orelse graphicsAndCompute.?);

    std.log.info("graphics queue index: {} transfer queue index: {} presentation queue index: {}", .{ graphicsQueueIndex, transferQueueIndex, presentationQueueIndex });

    var features12: vulkan.VkPhysicalDeviceVulkan12Features = undefined;
    features12.sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
    features12.pNext = null;

    var features11: vulkan.VkPhysicalDeviceVulkan11Features = undefined;
    features11.sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES;
    features11.pNext = &features12;

    var features: vulkan.VkPhysicalDeviceFeatures2 = undefined;
    features.sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    features.pNext = &features11;
    vulkan.vkGetPhysicalDeviceFeatures2(physicalDevices.items[foundDevice.?], &features);
    if (features.features.textureCompressionBC == 0) {
        std.log.err("Require support for BC texture compression", .{});
        return VulkanErrors.Fatal;
    }
    if (features.features.multiDrawIndirect == 0) {
        std.log.err("Require support for multi draw indirect", .{});
        return VulkanErrors.Fatal;
    }
    if (features11.uniformAndStorageBuffer16BitAccess == 0) {
        std.log.err("Require support for 16 bit types in buffers", .{});
        return VulkanErrors.Fatal;
    }
    if (features11.storagePushConstant16 == 0) {
        std.log.err("Require support for 16 bit types in push constants", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.drawIndirectCount == 0) {
        std.log.err("Require support for multi draw indirect", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderUniformTexelBufferArrayDynamicIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderStorageTexelBufferArrayDynamicIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderUniformBufferArrayNonUniformIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderSampledImageArrayNonUniformIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderStorageBufferArrayNonUniformIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderStorageImageArrayNonUniformIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.shaderUniformTexelBufferArrayNonUniformIndexing == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingSampledImageUpdateAfterBind == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingStorageImageUpdateAfterBind == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingStorageBufferUpdateAfterBind == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingUniformTexelBufferUpdateAfterBind == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingStorageTexelBufferUpdateAfterBind == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingUpdateUnusedWhilePending == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.descriptorBindingPartiallyBound == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }
    if (features12.uniformBufferStandardLayout == 0) {
        std.log.err("Require support for descriptor indexing", .{});
        return VulkanErrors.Fatal;
    }

    return physicalDevices.items[foundDevice.?];
}

pub fn initVulkan(extensions: [*c][*c]const u8, extensionCount: c_uint, window: ?*glfw.GLFWwindow) !void {
    var arenaTemp = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arenaTemp.deinit();
    const allocatorTemp = arenaTemp.allocator();

    var appInfo: vulkan.VkApplicationInfo = undefined;
    appInfo.sType = vulkan.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pNext = null;
    appInfo.pApplicationName = "Stars V5";
    appInfo.applicationVersion = 1;
    appInfo.pEngineName = "Stars V5";
    appInfo.engineVersion = 1;
    appInfo.apiVersion = vulkan.VK_API_VERSION_1_2;

    var createInfo: vulkan.VkInstanceCreateInfo = undefined;
    createInfo.sType = vulkan.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pNext = null;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledLayerCount = 0;
    createInfo.ppEnabledLayerNames = null;
    createInfo.flags = 0;
    createInfo.enabledExtensionCount = extensionCount;
    createInfo.ppEnabledExtensionNames = extensions;

    var result = vulkan.vkCreateInstance(&createInfo, null, &instance);
    if (result != vulkan.VK_SUCCESS) {
        return VulkanErrors.Fatal;
    }

    var glfwInstance: glfw.VkInstance = @ptrCast(glfw.VkInstance, instance);

    var glfwSurface: glfw.VkSurfaceKHR = undefined;
    result = glfw.glfwCreateWindowSurface(glfwInstance, window, null, &glfwSurface);
    if (result != vulkan.VK_SUCCESS) {
        return VulkanErrors.Fatal;
    }
    surface = @ptrCast(vulkan.VkSurfaceKHR, glfwSurface);

    var physDevice = try findDevice(allocatorTemp);
    _ = physDevice;
}

pub fn deInitVulkan() void {
    vulkan.vkDestroySurfaceKHR(instance, surface, null);
    vulkan.vkDestroyInstance(instance, null);
}
