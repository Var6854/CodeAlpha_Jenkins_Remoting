package com.codealpha.remoting;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests executed on remote Jenkins agent.
 */
class RemotingAppTest {

    private RemotingApp app;

    @BeforeEach
    void setUp() {
        app = new RemotingApp();
    }

    @Test
    @DisplayName("Test Addition Operation")
    void testAdd() {
        assertEquals(42, app.add(40, 2), "40 + 2 should equal 42");
        assertEquals(0, app.add(-5, 5), "-5 + 5 should equal 0");
    }

    @Test
    @DisplayName("Test Multiplication Operation")
    void testMultiply() {
        assertEquals(100, app.multiply(10, 10), "10 * 10 should equal 100");
        assertEquals(0, app.multiply(0, 50), "0 * 50 should equal 0");
    }

    @Test
    @DisplayName("Test Health Check")
    void testIsHealthy() {
        assertTrue(app.isHealthy(), "Application health check must return true");
    }

    @Test
    @DisplayName("Test Hostname Resolution")
    void testGetHostname() {
        String hostname = RemotingApp.getHostname();
        assertNotNull(hostname, "Hostname must not be null");
        assertFalse(hostname.isBlank(), "Hostname must not be blank");
    }
}
