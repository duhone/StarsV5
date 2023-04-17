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

const VulkanErrors = error{Fatal};

pub fn initVulkan(extensions: [*c][*c]const u8, extensionCount: c_uint, window: ?*glfw.GLFWwindow) !void {
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
}

pub fn deInitVulkan() void {
    vulkan.vkDestroySurfaceKHR(instance, surface, null);
    vulkan.vkDestroyInstance(instance, null);
}
