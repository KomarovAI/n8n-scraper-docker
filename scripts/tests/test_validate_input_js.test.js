/**
 * Unit tests for JavaScript input validation
 */

const { validateUrl, validateSelector } = require('../validate_input');

describe('URL Validation', () => {
  test('valid HTTPS URL should pass', () => {
    expect(() => validateUrl('https://example.com')).not.toThrow();
  });
  
  test('valid HTTP URL should pass', () => {
    expect(() => validateUrl('http://example.com')).not.toThrow();
  });
  
  test('localhost should be blocked', () => {
    expect(() => validateUrl('http://localhost:8080')).toThrow('Blocked host');
  });
  
  test('127.0.0.1 should be blocked', () => {
    expect(() => validateUrl('http://127.0.0.1')).toThrow('Blocked host');
  });
  
  test('private IP 10.x should be blocked', () => {
    expect(() => validateUrl('http://10.0.0.1')).toThrow('Private IP');
  });
  
  test('AWS metadata should be blocked', () => {
    expect(() => validateUrl('http://169.254.169.254')).toThrow('Blocked host');
  });
  
  test('FTP scheme should be rejected', () => {
    expect(() => validateUrl('ftp://example.com')).toThrow('Invalid scheme');
  });
});

describe('Selector Validation', () => {
  test('valid CSS selector should pass', () => {
    expect(() => validateSelector('div.class#id')).not.toThrow();
  });
  
  test('selector with quotes should be blocked', () => {
    expect(() => validateSelector('div"><script>')).toThrow('Invalid characters');
  });
  
  test('selector with semicolon should be blocked', () => {
    expect(() => validateSelector('div; DROP TABLE')).toThrow('Invalid characters');
  });
  
  test('too long selector should be blocked', () => {
    const longSelector = 'a'.repeat(501);
    expect(() => validateSelector(longSelector)).toThrow('too long');
  });
});
