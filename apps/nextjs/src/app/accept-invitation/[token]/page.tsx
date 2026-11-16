'use client';

import { UserOutlined, LockOutlined, EyeInvisibleOutlined, EyeTwoTone } from '@ant-design/icons';
import { Button, Form, Input, message, Card, Typography } from 'antd';
import Image from 'next/image';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import React, { useState, useEffect } from 'react';

import logoImage from '../../assets/images/logo.png';

const { Title, Text } = Typography;

type Props = {
  params: Promise<{ token: string }>
}

const AcceptInvitationPage = ({ params }: Props) => {
  const [token, setToken] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [validating, setValidating] = useState(true);
  const [tokenValid, setTokenValid] = useState(false);
  const [invitationInfo] = useState<{ email?: string; inviterName?: string; role?: string } | null>(null);
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

      // Validate the token format
      try {
        const response = await fetch('/api/auth/validate-invitation', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            token: resolvedParams.token,
          }),
        });

        if (response.ok) {
          setTokenValid(true);
          // Try to extract invitation info from the token if possible
          // For now, we'll just show the form
        } else {
          const data = await response.json();
          setTokenValid(false);
          if (data.message) {
            showMessage('error', data.message);
          }
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

  const onFinish = async (values: { firstname: string; lastname: string; password: string; confirmPassword: string }) => {
    if (values.password !== values.confirmPassword) {
      showMessage('error', 'Les mots de passe ne correspondent pas');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch('/api/auth/accept-invitation', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token,
          firstname: values.firstname,
          lastname: values.lastname,
          password: values.password,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        showMessage('success', 'Invitation acceptée avec succès ! Votre compte a été créé.');
        // Store auth token if provided
        if (data.token) {
          localStorage.setItem('authToken', data.token);
          if (data.userId) {
            localStorage.setItem('userId', data.userId.toString());
          }
        }
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
        showMessage('error', data.message || 'Erreur lors de l\'acceptation de l\'invitation');
      }
    } catch (error) {
      console.error('Accept invitation error:', error);
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
          border: 'none',
          padding: '40px',
          textAlign: 'center',
        }}>
          <Text style={{ color: '#6b7280', fontSize: '16px' }}>Chargement...</Text>
        </Card>
      </div>
    );
  }

  // Show error if token is invalid
  if (!tokenValid) {
    return (
      <div style={{

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
              height: '58px',
              position: 'relative',
              width: '58px',
              backgroundColor: 'red',
              borderRadius: '50%',
              padding: '10px',
              margin: '0 auto',
            }}>
              <Image
                src={logoImage}
                alt="Urbankiff Logo"
                fill
                style={{
                  objectFit: 'contain',
                }}
                priority
              />
            </div>
          </div>

          <Title level={2} style={{ color: '#ef4444', marginBottom: 16, fontSize: '24px' }}>
            Invitation invalide ou expirée
          </Title>
          <Text style={{ color: '#6b7280', marginBottom: 32, display: 'block', fontSize: '14px' }}>
            Ce lien d&apos;invitation n&apos;est plus valide ou a expiré. Veuillez contacter la personne qui vous a invité pour recevoir une nouvelle invitation.
          </Text>
          <Button
            type="primary"
            size="large"
            href="/fr"
            style={{
              height: 48,
              borderRadius: 8,
              backgroundColor: 'red',
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
  if (!token) {
    return (
      <div style={{

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
        border: 'none',

      }}>
        {/* Logo Section */}
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          {/* Logo Image */}
          <div style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            marginBottom: '16px',
            height: '58px',
            position: 'relative',
            width: '58px',
            backgroundColor: 'red',
            margin: '0 auto',
            borderRadius: '50%',
            padding: '10px',
          }}>
            <Image
              src={logoImage}
              alt="Urbankiff Logo"
              fill
              style={{
                objectFit: 'contain',
              }}
              priority
            />
          </div>

          {/* Title */}
          <Title level={2} style={{
            color: '#1f2937',
            marginBottom: 0,
            fontWeight: '600',
            fontSize: '24px',
          }}>
            Accepter l&apos;invitation
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
            Bienvenue !
          </Text>
          <Text style={{
            color: '#6b7280',
            fontSize: '14px',
            lineHeight: '1.5',
            marginBottom: '0',
          }}>
            {invitationInfo?.inviterName
              ? `${invitationInfo.inviterName} vous a invité à rejoindre Urbankiff.`
              : 'Vous avez été invité à rejoindre Urbankiff.'
            } Veuillez remplir le formulaire ci-dessous pour créer votre compte.
          </Text>
        </div>

        <Form
          form={form}
          name="accept-invitation"
          onFinish={onFinish}
          layout="vertical"
        >
          <Form.Item
            name="firstname"
            label={<span style={{ fontWeight: '600', color: '#374151', fontSize: '14px' }}>Prénom</span>}
            rules={[{ required: true, message: 'Veuillez saisir votre prénom' }]}
            style={{ marginBottom: '20px' }}
          >
            <Input
              prefix={<UserOutlined style={{ color: '#9ca3af' }} />}
              placeholder="Saisissez votre prénom"
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
            name="lastname"
            label={<span style={{ fontWeight: '600', color: '#374151', fontSize: '14px' }}>Nom</span>}
            rules={[{ required: true, message: 'Veuillez saisir votre nom' }]}
            style={{ marginBottom: '20px' }}
          >
            <Input
              prefix={<UserOutlined style={{ color: '#9ca3af' }} />}
              placeholder="Saisissez votre nom"
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
            name="password"
            label={<span style={{ fontWeight: '600', color: '#374151', fontSize: '14px' }}>Mot de passe</span>}
            rules={[{ validator: validatePassword }]}
            style={{ marginBottom: '20px' }}
          >
            <Input.Password
              prefix={<LockOutlined style={{ color: '#9ca3af' }} />}
              placeholder="Saisissez votre mot de passe"
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
              placeholder="Confirmez votre mot de passe"
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
                backgroundColor: 'red',
                fontSize: '16px',
                fontWeight: '600',
                pointerEvents: loading ? 'none' : 'auto',
                boxShadow: '0 2px 4px rgba(59, 130, 246, 0.2)',
              }}
            >
              Accepter l&apos;invitation
            </Button>
          </Form.Item>
        </Form>

        <div style={{ textAlign: 'center', marginTop: '32px' }}>
          <Text style={{ color: '#9ca3af', fontSize: '12px' }}>
            Vous rencontrez des problèmes ?{' '}
            <Link
              href="/fr/contact"
              style={{
                color: 'red',
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

export default AcceptInvitationPage;

