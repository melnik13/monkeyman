use utf8;
package HyperMouse::Schema::Result::Contractor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

HyperMouse::Schema::Result::Contractor

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<contractor>

=cut

__PACKAGE__->table("contractor");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 valid_since

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 valid_till

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 removed

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 contractor_type_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 provider

  data_type: 'tinyint'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "valid_since",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "valid_till",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "removed",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "contractor_type_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "provider",
  { data_type => "tinyint", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 contractor_type

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::ContractorType>

=cut

__PACKAGE__->belongs_to(
  "contractor_type",
  "HyperMouse::Schema::Result::ContractorType",
  { id => "contractor_type_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 partner_agreement_client_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::PartnerAgreement>

=cut

__PACKAGE__->has_many(
  "partner_agreement_client_contractors",
  "HyperMouse::Schema::Result::PartnerAgreement",
  { "foreign.client_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 partner_agreement_provider_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::PartnerAgreement>

=cut

__PACKAGE__->has_many(
  "partner_agreement_provider_contractors",
  "HyperMouse::Schema::Result::PartnerAgreement",
  { "foreign.provider_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 payment_client_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::Payment>

=cut

__PACKAGE__->has_many(
  "payment_client_contractors",
  "HyperMouse::Schema::Result::Payment",
  { "foreign.client_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 payment_provider_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::Payment>

=cut

__PACKAGE__->has_many(
  "payment_provider_contractors",
  "HyperMouse::Schema::Result::Payment",
  { "foreign.provider_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 person_x_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::PersonXContractor>

=cut

__PACKAGE__->has_many(
  "person_x_contractors",
  "HyperMouse::Schema::Result::PersonXContractor",
  { "foreign.contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 service_agreement_client_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::ServiceAgreement>

=cut

__PACKAGE__->has_many(
  "service_agreement_client_contractors",
  "HyperMouse::Schema::Result::ServiceAgreement",
  { "foreign.client_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 service_agreement_provider_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::ServiceAgreement>

=cut

__PACKAGE__->has_many(
  "service_agreement_provider_contractors",
  "HyperMouse::Schema::Result::ServiceAgreement",
  { "foreign.provider_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 writeoff_client_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::Writeoff>

=cut

__PACKAGE__->has_many(
  "writeoff_client_contractors",
  "HyperMouse::Schema::Result::Writeoff",
  { "foreign.client_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 writeoff_provider_contractors

Type: has_many

Related object: L<HyperMouse::Schema::Result::Writeoff>

=cut

__PACKAGE__->has_many(
  "writeoff_provider_contractors",
  "HyperMouse::Schema::Result::Writeoff",
  { "foreign.provider_contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-01-24 14:37:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:csXjt1MZGCaIIOuAREeo6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;