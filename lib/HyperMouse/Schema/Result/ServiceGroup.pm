use utf8;
package HyperMouse::Schema::Result::ServiceGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

HyperMouse::Schema::Result::ServiceGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::EncodedColumn>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "EncodedColumn");

=head1 TABLE: C<service_group>

=cut

__PACKAGE__->table("service_group");

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

=head2 service_family_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
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
  "service_family_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 service_family

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::ServiceFamily>

=cut

__PACKAGE__->belongs_to(
  "service_family",
  "HyperMouse::Schema::Result::ServiceFamily",
  { id => "service_family_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 service_group_i18ns

Type: has_many

Related object: L<HyperMouse::Schema::Result::ServiceGroupI18n>

=cut

__PACKAGE__->has_many(
  "service_group_i18ns",
  "HyperMouse::Schema::Result::ServiceGroupI18n",
  { "foreign.service_group_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 service_types

Type: has_many

Related object: L<HyperMouse::Schema::Result::ServiceType>

=cut

__PACKAGE__->has_many(
  "service_types",
  "HyperMouse::Schema::Result::ServiceType",
  { "foreign.service_group_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-01-31 15:54:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BUYAZ5KdbGBBaHmU+L0PZg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
