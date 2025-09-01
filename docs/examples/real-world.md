# Real World Use Cases

This section presents complete, production-ready examples of PromptManager in real-world scenarios.

## E-commerce Platform

### Customer Communication System

A complete customer notification system for an e-commerce platform.

#### Directory Structure

```
prompts/
├── ecommerce/
│   ├── orders/
│   │   ├── confirmation.txt
│   │   ├── shipped.txt
│   │   ├── delivered.txt
│   │   └── cancelled.txt
│   ├── customers/
│   │   ├── welcome.txt
│   │   ├── password_reset.txt
│   │   └── account_suspension.txt
│   └── marketing/
│       ├── newsletter.txt
│       ├── sale_announcement.txt
│       └── product_recommendation.txt
└── shared/
    ├── headers/
    │   ├── brand_header.txt
    │   └── legal_header.txt
    └── footers/
        ├── unsubscribe_footer.txt
        └── contact_footer.txt
```

#### Implementation

```ruby
# app/services/customer_notification_service.rb
class CustomerNotificationService
  include ActiveModel::Validations
  
  validates :customer, presence: true
  validates :notification_type, inclusion: {
    in: %w[order_confirmation order_shipped order_delivered order_cancelled
           welcome password_reset account_suspension newsletter sale_announcement]
  }
  
  def initialize(customer:, notification_type:, data: {})
    @customer = customer
    @notification_type = notification_type
    @data = data
  end
  
  def deliver
    return false unless valid?
    
    content = render_notification
    send_notification(content)
    log_notification
    
    true
  rescue => e
    handle_error(e)
    false
  end
  
  private
  
  attr_reader :customer, :notification_type, :data
  
  def render_notification
    prompt_id = "ecommerce/#{notification_category}/#{notification_type.split('_').last}"
    
    prompt = PromptManager::Prompt.new(
      id: prompt_id,
      erb_flag: true,
      envar_flag: true
    )
    
    prompt.render(notification_parameters)
  end
  
  def notification_category
    case notification_type
    when /^order_/ then 'orders'
    when /^(welcome|password_reset|account_suspension)$/ then 'customers'
    else 'marketing'
    end
  end
  
  def notification_parameters
    base_params = {
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_id: customer.id,
      company_name: ENV['COMPANY_NAME'],
      support_email: ENV['SUPPORT_EMAIL'],
      website_url: ENV['WEBSITE_URL']
    }
    
    base_params.merge(notification_specific_params)
  end
  
  def notification_specific_params
    case notification_type
    when 'order_confirmation'
      order_confirmation_params
    when 'order_shipped'
      order_shipped_params
    when 'product_recommendation'
      recommendation_params
    else
      data
    end
  end
  
  def order_confirmation_params
    order = data[:order]
    {
      order_id: order.id,
      order_date: order.created_at.strftime('%B %d, %Y'),
      order_total: sprintf('%.2f', order.total),
      order_items: order.line_items.map { |item|
        "#{item.quantity}x #{item.product.name} - $#{sprintf('%.2f', item.total)}"
      },
      estimated_delivery: (order.created_at + order.shipping_method.estimated_days.days).strftime('%B %d, %Y'),
      tracking_url: "#{ENV['WEBSITE_URL']}/orders/#{order.id}/track"
    }
  end
  
  def order_shipped_params
    order = data[:order]
    shipment = data[:shipment]
    {
      order_id: order.id,
      tracking_number: shipment.tracking_number,
      carrier: shipment.carrier.name,
      carrier_tracking_url: shipment.carrier_tracking_url,
      estimated_delivery: shipment.estimated_delivery_date.strftime('%B %d, %Y'),
      shipped_items: shipment.line_items.map { |item|
        "#{item.quantity}x #{item.product.name}"
      }
    }
  end
  
  def recommendation_params
    recommendations = data[:recommendations]
    {
      recommended_products: recommendations.map { |product|
        {
          name: product.name,
          price: sprintf('%.2f', product.price),
          image_url: product.primary_image.url,
          product_url: "#{ENV['WEBSITE_URL']}/products/#{product.slug}",
          discount_percentage: product.current_discount&.percentage || 0
        }
      },
      recommendation_reason: data[:reason] || 'Based on your recent purchases'
    }
  end
  
  def send_notification(content)
    case customer.preferred_notification_method
    when 'email'
      send_email(content)
    when 'sms'
      send_sms(content)
    when 'push'
      send_push_notification(content)
    else
      send_email(content)  # Default fallback
    end
  end
  
  def send_email(content)
    CustomerNotificationMailer.custom_notification(
      customer: customer,
      subject: email_subject,
      content: content,
      notification_type: notification_type
    ).deliver_later
  end
  
  def email_subject
    case notification_type
    when 'order_confirmation' then "Order Confirmation ##{data[:order].id}"
    when 'order_shipped' then "Your Order Has Shipped! ##{data[:order].id}"
    when 'order_delivered' then "Order Delivered ##{data[:order].id}"
    when 'welcome' then "Welcome to #{ENV['COMPANY_NAME']}!"
    when 'password_reset' then "Password Reset Request"
    when 'newsletter' then data[:subject] || "Newsletter"
    else "Notification from #{ENV['COMPANY_NAME']}"
    end
  end
  
  def log_notification
    CustomerNotificationLog.create!(
      customer: customer,
      notification_type: notification_type,
      delivery_method: customer.preferred_notification_method,
      data: data,
      delivered_at: Time.current
    )
  end
  
  def handle_error(error)
    Rails.logger.error "Notification delivery failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    ErrorReportingService.notify(error, {
      customer_id: customer.id,
      notification_type: notification_type,
      data: data
    })
  end
end
```

#### Prompt Templates

```ruby
# prompts/ecommerce/orders/confirmation.txt
//include shared/headers/brand_header.txt

Dear [CUSTOMER_NAME],

Thank you for your order! We're excited to confirm that we've received your order and it's being processed.

**Order Details:**
Order #: [ORDER_ID]
Order Date: [ORDER_DATE]
Total: $[ORDER_TOTAL]

**Items Ordered:**
<% '[ORDER_ITEMS]'.each do |item| %>
• <%= item %>
<% end %>

**Shipping Information:**
Estimated Delivery: [ESTIMATED_DELIVERY]
You can track your order at: [TRACKING_URL]

<% if '[ORDER_TOTAL]'.to_f > 75 %>
🎉 **Free Shipping Applied!** - You saved $9.99
<% end %>

We'll send you another email when your order ships with tracking information.

//include shared/footers/contact_footer.txt

# prompts/ecommerce/orders/shipped.txt  
//include shared/headers/brand_header.txt

Great news, [CUSTOMER_NAME]!

Your order #[ORDER_ID] has shipped and is on its way to you.

**Shipping Details:**
📦 Carrier: [CARRIER]
🚚 Tracking Number: [TRACKING_NUMBER]
📅 Estimated Delivery: [ESTIMATED_DELIVERY]

**Track Your Package:**
[CARRIER_TRACKING_URL]

**Items Shipped:**
<% '[SHIPPED_ITEMS]'.each do |item| %>
✓ <%= item %>
<% end %>

Your package should arrive by [ESTIMATED_DELIVERY]. If you have any questions, don't hesitate to reach out!

//include shared/footers/contact_footer.txt

# prompts/ecommerce/marketing/product_recommendation.txt
//include shared/headers/brand_header.txt

Hi [CUSTOMER_NAME],

We thought you might be interested in these products [RECOMMENDATION_REASON]:

<% '[RECOMMENDED_PRODUCTS]'.each do |product| %>
**<%= product['name'] %>**
<% if product['discount_percentage'] > 0 %>
~~$<%= (product['price'].to_f / (1 - product['discount_percentage']/100.0)).round(2) %>~~ **$<%= product['price'] %>** (<%= product['discount_percentage'] %>% OFF!)
<% else %>
$<%= product['price'] %>
<% end %>
[View Product](<%= product['product_url'] %>)

<% end %>

These recommendations expire in 48 hours, so don't wait too long!

Happy shopping!
The [COMPANY_NAME] Team

//include shared/footers/unsubscribe_footer.txt
```

#### Usage Examples

```ruby
# Order confirmation
CustomerNotificationService.new(
  customer: current_user,
  notification_type: 'order_confirmation',
  data: { order: @order }
).deliver

# Shipping notification
CustomerNotificationService.new(
  customer: order.customer,
  notification_type: 'order_shipped', 
  data: { 
    order: order,
    shipment: shipment
  }
).deliver

# Product recommendations
CustomerNotificationService.new(
  customer: user,
  notification_type: 'product_recommendation',
  data: {
    recommendations: RecommendationEngine.for_user(user),
    reason: "based on your recent purchase of #{user.recent_orders.first.product_names.first}"
  }
).deliver
```

## SaaS Application

### Multi-tenant Onboarding System

A complete onboarding workflow for a SaaS platform with multiple client organizations.

```ruby
# app/services/onboarding_workflow_service.rb
class OnboardingWorkflowService
  WORKFLOW_STEPS = %w[
    welcome
    account_setup_instructions
    feature_introduction
    integration_guide
    first_milestone_celebration
    getting_help
  ].freeze
  
  def initialize(organization:, user:)
    @organization = organization
    @user = user
    @step = 0
  end
  
  def start_workflow
    schedule_step(0, delay: 0.minutes)
  end
  
  def complete_step(step_name)
    step_index = WORKFLOW_STEPS.index(step_name)
    return false unless step_index
    
    @organization.onboarding_progress.update!(
      completed_steps: @organization.onboarding_progress.completed_steps | [step_name],
      current_step: WORKFLOW_STEPS[step_index + 1]
    )
    
    schedule_next_step(step_index + 1)
    true
  end
  
  private
  
  def schedule_step(step_index, delay: 1.day)
    return if step_index >= WORKFLOW_STEPS.length
    
    OnboardingEmailJob.set(wait: delay).perform_later(
      organization_id: @organization.id,
      user_id: @user.id,
      step: WORKFLOW_STEPS[step_index]
    )
  end
  
  def schedule_next_step(step_index)
    delays = {
      0 => 0.minutes,    # welcome - immediate
      1 => 1.hour,       # setup instructions
      2 => 1.day,        # feature intro  
      3 => 3.days,       # integration guide
      4 => 1.week,       # milestone celebration
      5 => 2.weeks       # getting help
    }
    
    schedule_step(step_index, delay: delays[step_index] || 3.days)
  end
end

# app/jobs/onboarding_email_job.rb
class OnboardingEmailJob < ApplicationJob
  def perform(organization_id:, user_id:, step:)
    organization = Organization.find(organization_id)
    user = User.find(user_id)
    
    prompt = PromptManager::Prompt.new(
      id: "saas/onboarding/#{step}",
      erb_flag: true
    )
    
    content = prompt.render(
      user_name: user.first_name,
      user_email: user.email,
      organization_name: organization.name,
      organization_plan: organization.current_plan.name,
      organization_members_count: organization.users.count,
      setup_url: "#{ENV['APP_URL']}/setup?org=#{organization.id}",
      dashboard_url: "#{ENV['APP_URL']}/dashboard?org=#{organization.id}",
      support_url: "#{ENV['APP_URL']}/support",
      app_name: ENV['APP_NAME'],
      days_since_signup: (Date.current - organization.created_at.to_date).to_i
    )
    
    OnboardingMailer.workflow_step(
      user: user,
      organization: organization,
      step: step,
      content: content
    ).deliver_now
    
    # Track email delivery
    organization.onboarding_progress.increment!("#{step}_emails_sent")
  end
end
```

#### Onboarding Prompt Templates

```ruby
# prompts/saas/onboarding/welcome.txt
<%= erb_flag = true %>

Hi [USER_NAME]! 👋

Welcome to [APP_NAME]! We're thrilled to have [ORGANIZATION_NAME] join our platform.

Over the next few weeks, I'll be sending you a series of emails to help you get the most out of [APP_NAME]. Here's what to expect:

📋 **Next up (in about an hour):** Account setup guide
🚀 **Tomorrow:** Feature walkthrough 
🔧 **In 3 days:** Integration setup help
🎉 **Next week:** Celebrating your first milestone

**Quick Start:**
Ready to dive in right now? Visit your dashboard: [DASHBOARD_URL]

<% if '[ORGANIZATION_PLAN]' == 'trial' %>
⏰ **Trial Reminder:** You have <%= 30 - '[DAYS_SINCE_SIGNUP]'.to_i %> days left in your trial. We'll help you make the most of it!
<% end %>

Looking forward to your success!
Sarah from the [APP_NAME] team

P.S. Hit reply anytime - I read every email personally! 📧

# prompts/saas/onboarding/account_setup_instructions.txt  
<%= erb_flag = true %>

Hey [USER_NAME],

Ready to set up your [APP_NAME] account? Let's get [ORGANIZATION_NAME] fully configured! 

**Your 5-Minute Setup Checklist:**
□ Complete your organization profile
□ Invite your team members (<%= '[ORGANIZATION_MEMBERS_COUNT]'.to_i == 1 ? "You're flying solo for now!" : "You have #{[ORGANIZATION_MEMBERS_COUNT].to_i} members so far" %>)
□ Connect your first integration  
□ Set up your preferences
□ Take our product tour

**Start Setup: [SETUP_URL]**

<% if '[ORGANIZATION_PLAN]' == 'enterprise' %>
🏢 **Enterprise Customer?** 
Your dedicated success manager will reach out within 24 hours to schedule a personalized onboarding call.
<% end %>

**Need help?** 
- 📖 Check our setup guide: [SETUP_URL]/guide
- 💬 Live chat support: [SUPPORT_URL]  
- 📧 Just reply to this email

You've got this!
Sarah 🌟

# prompts/saas/onboarding/feature_introduction.txt
<%= erb_flag = true %>

Hi [USER_NAME]!

Hope you're settling in well with [APP_NAME]! Today I want to show you three features that [ORGANIZATION_PLAN] customers love most:

**🎯 Smart Analytics**
Get insights into your data with our AI-powered analytics. Perfect for understanding trends and making data-driven decisions.
[Learn more →]([DASHBOARD_URL]/analytics)

**🔄 Automation Workflows** 
<% if '[ORGANIZATION_PLAN]' == 'enterprise' %>
Set up complex automation rules to streamline your processes. Enterprise customers can create unlimited workflows!
<% else %>
Automate repetitive tasks with our visual workflow builder. Your plan includes up to 10 active workflows.
<% end %>
[See examples →]([DASHBOARD_URL]/workflows)

**👥 Team Collaboration**
Share dashboards, leave comments, and keep everyone in sync.
[Invite teammates →]([SETUP_URL]/team)

**Pro tip:** Most successful teams start with automation workflows. They save an average of 5 hours per week! 

Want a personal demo of any of these features? Just reply and I'll set something up.

Cheers,
Sarah 🚀

# prompts/saas/onboarding/integration_guide.txt
<%= erb_flag = true %>

Hey [USER_NAME],

Ready to supercharge [APP_NAME] with integrations? Let's connect your existing tools!

**Popular Integrations for [ORGANIZATION_PLAN] teams:**

🔗 **CRM Integration** (Salesforce, HubSpot, Pipedrive)
Sync your customer data automatically
[Connect now →]([SETUP_URL]/integrations/crm)

📧 **Email Marketing** (Mailchimp, ConvertKit, Klaviyo)  
Trigger campaigns based on your [APP_NAME] data
[Set up →]([SETUP_URL]/integrations/email)

📊 **Analytics** (Google Analytics, Mixpanel, Segment)
Get deeper insights by combining data sources
[Integrate →]([SETUP_URL]/integrations/analytics)

<% if '[ORGANIZATION_PLAN]' == 'enterprise' %>
🏢 **Enterprise Exclusive:**
- Custom API integrations
- SSO setup (SAML, OAuth)
- Database connections
[Contact your success manager for setup]
<% end %>

**Integration taking longer than expected?** 
Our integration specialists can help! Book a free 30-minute session: [SUPPORT_URL]/integration-help

Keep building,
Sarah ⚡

# prompts/saas/onboarding/first_milestone_celebration.txt
<%= erb_flag = true %>

🎉 [USER_NAME], you did it!

It's been a week since [ORGANIZATION_NAME] joined [APP_NAME], and I wanted to celebrate some awesome progress:

**Your Week 1 Achievements:**
<% days_active = '[DAYS_SINCE_SIGNUP]'.to_i %>
✅ Account active for <%= days_active %> <%= days_active == 1 ? 'day' : 'days' %>
<% if '[ORGANIZATION_MEMBERS_COUNT]'.to_i > 1 %>
✅ Team of <%= '[ORGANIZATION_MEMBERS_COUNT]' %> members onboarded
<% end %>
✅ Dashboard configured and personalized

**What's Working Well:**
Most teams at your stage are focusing on:
- Setting up their first automated workflows (saves ~5 hours/week)
- Connecting 2-3 key integrations  
- Training team members on core features

**Quick Win for Week 2:**
Try our "Smart Automation" feature - it suggests workflows based on your usage patterns.
[Check it out →]([DASHBOARD_URL]/automation/suggestions)

<% if '[ORGANIZATION_PLAN]' == 'trial' %>
⏰ **Trial Update:** <%= 30 - days_active %> days remaining
Ready to upgrade? Current customers save 20% on annual plans: [DASHBOARD_URL]/billing
<% end %>

You're building something great! Keep going 💪

Sarah & the [APP_NAME] team

P.S. Have a success story to share? I'd love to hear it! 🌟
```

## Healthcare System

### Patient Communication Platform

A HIPAA-compliant patient communication system for healthcare providers.

```ruby
# app/services/patient_communication_service.rb  
class PatientCommunicationService
  include EncryptionHelper
  
  def initialize(patient:, provider:, communication_type:)
    @patient = patient
    @provider = provider  
    @communication_type = communication_type
    validate_hipaa_compliance!
  end
  
  def send_appointment_reminder(appointment)
    send_secure_communication(
      'healthcare/appointments/reminder',
      appointment_reminder_params(appointment)
    )
  end
  
  def send_test_results(test_result)
    send_secure_communication(
      'healthcare/results/lab_results',
      test_results_params(test_result)
    )
  end
  
  def send_medication_reminder(prescription)
    send_secure_communication(
      'healthcare/medications/reminder', 
      medication_params(prescription)
    )
  end
  
  private
  
  def send_secure_communication(prompt_id, parameters)
    # Generate encrypted message
    prompt = PromptManager::Prompt.new(id: prompt_id)
    content = prompt.render(parameters)
    
    encrypted_content = encrypt_phi(content)
    
    # Send via secure channel
    case @patient.preferred_communication_method
    when 'secure_email'
      send_encrypted_email(encrypted_content)
    when 'patient_portal' 
      post_to_patient_portal(encrypted_content)
    when 'secure_sms'
      send_encrypted_sms(encrypted_content)
    end
    
    # Log communication (HIPAA audit trail)
    log_patient_communication(prompt_id, parameters)
  end
  
  def appointment_reminder_params(appointment)
    {
      patient_first_name: @patient.first_name,
      appointment_date: appointment.scheduled_at.strftime('%A, %B %d, %Y'),
      appointment_time: appointment.scheduled_at.strftime('%I:%M %p'),
      provider_name: @provider.full_name,
      provider_title: @provider.title,
      clinic_name: @provider.clinic.name,
      clinic_address: @provider.clinic.address,
      clinic_phone: format_phone(@provider.clinic.phone),
      appointment_type: appointment.appointment_type.name,
      preparation_instructions: appointment.preparation_instructions,
      insurance_reminder: insurance_verification_needed?(appointment)
    }
  end
  
  def test_results_params(test_result)
    {
      patient_first_name: @patient.first_name,
      test_name: test_result.test_type.name,
      test_date: test_result.collected_at.strftime('%B %d, %Y'),
      ordering_provider: test_result.ordering_provider.full_name,
      results_summary: sanitize_phi(test_result.summary),
      next_steps: test_result.recommendations,
      followup_needed: test_result.requires_followup?,
      portal_url: "#{ENV['PATIENT_PORTAL_URL']}/results/#{test_result.secure_id}"
    }
  end
  
  def validate_hipaa_compliance!
    raise 'HIPAA compliance not configured' unless Rails.application.config.hipaa_enabled
    raise 'Encryption not available' unless encryption_available?
    raise 'Audit logging disabled' unless audit_logging_enabled?
  end
end
```

#### Healthcare Prompt Templates

```ruby
# prompts/healthcare/appointments/reminder.txt
Dear [PATIENT_FIRST_NAME],

This is a friendly reminder about your upcoming appointment:

**Appointment Details:**
📅 Date: [APPOINTMENT_DATE]  
🕐 Time: [APPOINTMENT_TIME]
👩‍⚕️ Provider: [PROVIDER_NAME], [PROVIDER_TITLE]
🏥 Location: [CLINIC_NAME]
📍 Address: [CLINIC_ADDRESS]
📞 Phone: [CLINIC_PHONE]

**Appointment Type:** [APPOINTMENT_TYPE]

<% if ![PREPARATION_INSTRUCTIONS].empty? %>
**Important Preparation Instructions:**
[PREPARATION_INSTRUCTIONS]
<% end %>

<% if [INSURANCE_REMINDER] %>
**Insurance Reminder:** 
Please bring your current insurance card and a valid photo ID.
<% end %>

**Need to reschedule?** 
Please call us at [CLINIC_PHONE] at least 24 hours in advance.

**Running late?**
Please call to let us know - we'll do our best to accommodate you.

Thank you for choosing [CLINIC_NAME] for your healthcare needs.

---
This message contains confidential medical information intended only for [PATIENT_FIRST_NAME]. If you received this in error, please contact [CLINIC_PHONE] immediately.

# prompts/healthcare/results/lab_results.txt  
Dear [PATIENT_FIRST_NAME],

Your recent lab results from [TEST_DATE] are now available.

**Test:** [TEST_NAME]
**Ordered by:** [ORDERING_PROVIDER]

**Results Summary:**
[RESULTS_SUMMARY]

<% if [NEXT_STEPS] %>
**Recommended Next Steps:**
[NEXT_STEPS]
<% end %>

<% if [FOLLOWUP_NEEDED] %>
**⚠️ Follow-up Required**
Please schedule a follow-up appointment to discuss these results in detail.
Call [CLINIC_PHONE] or use our patient portal.
<% else %>
**✅ No Follow-up Needed**
These results are within normal ranges. Continue your current care plan.
<% end %>

**View Complete Results:**
Log into your patient portal for detailed results and reference ranges:
[PORTAL_URL]

**Questions about your results?**
Contact your care team at [CLINIC_PHONE] or send a secure message through the patient portal.

Best regards,
[ORDERING_PROVIDER] and Care Team

---
CONFIDENTIAL: This message contains protected health information. Do not forward or share.
```

These real-world examples demonstrate how PromptManager can be used to build sophisticated, production-ready communication systems across different industries while maintaining security, compliance, and scalability requirements.