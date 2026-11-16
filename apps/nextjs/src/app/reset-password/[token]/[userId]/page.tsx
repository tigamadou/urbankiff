'use client';

import { LockOutlined, EyeInvisibleOutlined, EyeTwoTone } from '@ant-design/icons';
import { Button, Form, Input, message, Card, Typography } from 'antd';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import React, { useState, useEffect } from 'react';

const { Title, Text } = Typography;

type Props = {
  params: Promise<{ token: string; userId: string }>
}

const ResetPasswordPage = ({ params }: Props) => {
  const [token, setToken] = useState<string>('');
  const [userId, setUserId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [validating, setValidating] = useState(true);
  const [tokenValid, setTokenValid] = useState(false);
  const [form] = Form.useForm();
  const router = useRouter();

  // Custom message handler to avoid Ant Design message issues
  const showMessage = (type: 'success' | 'error', content: string) => {
    try {
      if (type === 'success') {
        message.success(content);
      } else {
        message.error(content);
      }
    } catch (error) {
      console.warn('Message display error:', error);
      // Fallback to native alert
      alert(content);
    }
  };

  useEffect(() => {
    const getParamsAndValidate = async () => {
      const resolvedParams = await params;
      setToken(resolvedParams.token);
      setUserId(resolvedParams.userId);

      // Validate the token
      try {
        const response = await fetch('/api/auth/validate-reset-token', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            token: resolvedParams.token,
            userId: resolvedParams.userId,
          }),
        });

        if (response.ok) {
          setTokenValid(true);
        } else {
          setTokenValid(false);
        }
      } catch (error) {
        console.error('Token validation error:', error);
        setTokenValid(false);
      } finally {
        setValidating(false);
      }
    };
    getParamsAndValidate();
  }, [params]);

  // Cleanup effect to prevent wave effect errors
  useEffect(() => {
    return () => {
      // Cleanup any pending animations or effects
      setLoading(false);
      setValidating(false);
    };
  }, []);

  const onFinish = async (values: { password: string; confirmPassword: string }) => {
    if (values.password !== values.confirmPassword) {
      showMessage('error', 'Les mots de passe ne correspondent pas');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch('/api/auth/reset-password', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token,
          userId,
          password: values.password,
        }),
      });

      const data = await response.json();
      if (response.ok) {
        showMessage('success', 'Mot de passe réinitialisé avec succès');
        // Add a small delay to prevent wave effect issues
        setTimeout(() => {
          try {
            router.push('/fr');
          } catch (navError) {
            console.warn('Navigation error:', navError);
            window.location.href = '/fr';
          }
        }, 100);
      } else {
        showMessage('error', data.message || 'Erreur lors de la réinitialisation du mot de passe');
      }
    } catch (error) {
      console.error('Reset password error:', error);
      showMessage('error', 'Une erreur est survenue. Veuillez réessayer.');
    } finally {
      setLoading(false);
    }
  };

  const validatePassword = (_: unknown, value: string) => {
    if (!value) {
      return Promise.reject(new Error('Veuillez saisir un mot de passe'));
    }
    if (value.length < 8) {
      return Promise.reject(new Error('Le mot de passe doit contenir au moins 8 caractères'));
    }
    return Promise.resolve();
  };

  const validateConfirmPassword = (_: unknown, value: string) => {
    if (!value) {
      return Promise.reject(new Error('Veuillez confirmer votre mot de passe'));
    }
    if (value !== form.getFieldValue('password')) {
      return Promise.reject(new Error('Les mots de passe ne correspondent pas'));
    }
    return Promise.resolve();
  };

  // Show loading state while validating
  if (validating) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#f8f9fa',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}>
        <Card style={{
          width: '100%',
          maxWidth: 480,
          borderRadius: 16,
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
          border: 'none',
          padding: '40px',
          textAlign: 'center',
        }}>
          <Text style={{ color: '#6b7280', fontSize: '16px' }}>Chargement...</Text>
        </Card>
      </div>
    );
  }

  // Show 404 if token is invalid
  if (!tokenValid) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#f8f9fa',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}>
        <Card style={{
          width: '100%',
          maxWidth: 480,
          borderRadius: 16,
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
          border: 'none',
          padding: '40px',
          textAlign: 'center',
        }}>
          {/* Logo Section */}
          <div style={{ marginBottom: 32 }}>
            <div style={{
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              marginBottom: '16px',
              height: '48px',
            }}>
              <img
                src="/logo.png"
                alt="Urbankiff Logo"
                style={{
                  height: '48px',
                  width: 'auto',
                  maxWidth: '200px',
                }}
              />
            </div>
          </div>

          <Title level={2} style={{ color: '#ef4444', marginBottom: 16, fontSize: '24px' }}>
            Token invalide ou expiré
          </Title>
          <Text style={{ color: '#6b7280', marginBottom: 32, display: 'block', fontSize: '14px' }}>
            Ce lien de réinitialisation n&apos;est plus valide ou a expiré.
          </Text>
          <Button
            type="primary"
            size="large"
            href="/fr"
            style={{
              height: 48,
              borderRadius: 8,
              backgroundColor: '#3b82f6',
              borderColor: '#3b82f6',
              fontSize: '16px',
              fontWeight: '600',
              boxShadow: '0 2px 4px rgba(59, 130, 246, 0.2)',
            }}
          >
            Retour à l&apos;accueil
          </Button>
        </Card>
      </div>
    );
  }

  // Show form if token is valid
  if (!token || !userId) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#f8f9fa',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}>
        <Text style={{ color: '#6b7280', fontSize: '16px' }}>Chargement...</Text>
      </div>
    );
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: '#f8f9fa',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '20px',
      fontFamily: 'system-ui, -apple-system, sans-serif',
    }}>
      <Card style={{
        width: '100%',
        maxWidth: 480,
        borderRadius: 16,
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
        border: 'none',
        padding: '40px',
      }}>
        {/* Logo Section */}
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          {/* Logo Image */}
          <div style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            marginBottom: '16px',
            height: '48px',
          }}>
            <img
              src="/logo.png"
              alt="Urbankiff Logo"
              style={{
                height: '48px',
                width: 'auto',
                maxWidth: '200px',
              }}
            />
          </div>

          {/* Title */}
          <Title level={2} style={{
            color: '#1f2937',
            marginBottom: 0,
            fontWeight: '600',
            fontSize: '24px',
          }}>
            Réinitialiser votre mot de passe
          </Title>

          {/* Divider Line */}
          <div style={{
            width: '60px',
            height: '2px',
            backgroundColor: '#e5e7eb',
            margin: '16px auto 0',
            borderRadius: '1px',
          }} />
        </div>

        {/* Greeting */}
        <div style={{ marginBottom: 24 }}>
          <Text style={{
            color: '#1f2937',
            fontSize: '16px',
            fontWeight: '600',
            marginBottom: '8px',
            display: 'block',
          }}>
            Bonjour,
          </Text>
          <Text style={{
            color: '#6b7280',
            fontSize: '14px',
            lineHeight: '1.5',
            marginBottom: '0',
          }}>
            Veuillez saisir votre nouveau mot de passe ci-dessous. Si vous n&apos;avez pas demandé cette réinitialisation, vous pouvez ignorer cette page.
          </Text>
        </div>

        <Form
          form={form}
          name="reset-password"
          onFinish={onFinish}
          layout="vertical"
        >
          <Form.Item
            name="password"
            label={<span style={{ fontWeight: '600', color: '#374151', fontSize: '14px' }}>Nouveau mot de passe</span>}
            rules={[{ validator: validatePassword }]}
            style={{ marginBottom: '20px' }}
          >
            <Input.Password
              prefix={<LockOutlined style={{ color: '#9ca3af' }} />}
              placeholder="Saisissez votre nouveau mot de passe"
              iconRender={(visible) => (visible ? <EyeTwoTone /> : <EyeInvisibleOutlined />)}
              style={{
                height: 48,
                borderRadius: 8,
                border: '1px solid #d1d5db',
                fontSize: '14px',
                padding: '0 12px',
              }}
            />
          </Form.Item>

          <Form.Item
            name="confirmPassword"
            label={<span style={{ fontWeight: '600', color: '#374151', fontSize: '14px' }}>Confirmer le mot de passe</span>}
            rules={[{ validator: validateConfirmPassword }]}
            style={{ marginBottom: '32px' }}
          >
            <Input.Password
              prefix={<LockOutlined style={{ color: '#9ca3af' }} />}
              placeholder="Confirmez votre nouveau mot de passe"
              iconRender={(visible) => (visible ? <EyeTwoTone /> : <EyeInvisibleOutlined />)}
              style={{
                height: 48,
                borderRadius: 8,
                border: '1px solid #d1d5db',
                fontSize: '14px',
                padding: '0 12px',
              }}
            />
          </Form.Item>

          <Form.Item style={{ marginBottom: 0 }}>
            <Button
              type="primary"
              htmlType="submit"
              loading={loading}
              block
              size="large"
              disabled={loading}
              style={{
                height: 48,
                borderRadius: 8,
                backgroundColor: '#3b82f6',
                borderColor: '#3b82f6',
                fontSize: '16px',
                fontWeight: '600',
                pointerEvents: loading ? 'none' : 'auto',
                boxShadow: '0 2px 4px rgba(59, 130, 246, 0.2)',
              }}
            >
              Réinitialiser le mot de passe
            </Button>
          </Form.Item>
        </Form>

        <div style={{ textAlign: 'center', marginTop: '32px' }}>
          <Text style={{ color: '#9ca3af', fontSize: '12px' }}>
            Vous rencontrez des problèmes ?{' '}
            <Link
              href="/fr/contact"
              style={{
                color: '#3b82f6',
                textDecoration: 'none',
                fontWeight: '500',
              }}
            >
              Contactez le support
            </Link>
          </Text>
        </div>
      </Card>
    </div>
  );
};

export default ResetPasswordPage;
